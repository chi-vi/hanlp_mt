# DeprelRules - Grammar Transformation Rules
# Sử dụng trực tiếp deprel gốc từ SD-Chinese cho quy luật ngữ pháp
# See: doc/annotations/dep-sd_zh.md
#
# LƯU Ý: Module này chỉ xử lý biến đổi cấu trúc, KHÔNG tra nghĩa từ
# Việc tra nghĩa sử dụng DRT (xem: drt.cr)

require "../node"

module Zh2Vi::Rules
  module DeprelRules
    # Phân loại deprel theo hành động cần thực hiện
    enum Action
      Reorder   # Đảo vị trí (amod, nn, rcmod, assmod)
      Transform # Biến đổi cấu trúc (ba, pass, loc)
      Merge     # Gộp tokens (dobj trong ly hợp)
      Skip      # Bỏ qua - không xử lý
    end

    # Xác định action cho deprel gốc
    def self.action_for(deprel : String) : Action
      case deprel
      # Đảo vị trí: định ngữ ra sau danh từ
      when "amod", "nn", "rcmod", "assmod", "det"
        Action::Reorder
        # Biến đổi cấu trúc đặc biệt
      when "ba" # 把 construction
        Action::Transform
      when "pass" # 被 passive
        Action::Transform
      when "loc", "lobj", "plmod" # Phương vị từ
        Action::Transform
        # Gộp tokens (ly hợp, bổ ngữ)
      when "dobj"
        Action::Merge # Có thể là ly hợp, cần kiểm tra
      when "rcomp"
        Action::Merge # Bổ ngữ kết quả gộp với động từ
      else
        Action::Skip
      end
    end

    # Các deprel cần đảo vị trí
    REORDER_DEPRELS = %w[amod nn rcmod assmod det tmod]

    # Các deprel cấu trúc đặc biệt
    STRUCTURAL_DEPRELS = %w[ba pass loc lobj plmod]

    # Danh sách động từ ly hợp
    LIHECI = {
      "帮忙", "睡觉", "吃饭", "上班", "下班",
      "游泳", "跳舞", "唱歌", "跑步", "散步",
      "洗澡", "理发", "结婚", "离婚", "毕业",
      "见面", "打架", "吵架", "发烧", "生气",
    }

    # Phương vị từ
    LOCALIZERS = {"上", "下", "里", "外", "前", "后", "左", "右", "中", "内", "旁"}

    # Bổ ngữ xu hướng
    DIRECTION_COMPLEMENTS = {
      "来", "去", "上", "下", "进", "出", "回",
      "过", "起", "开", "起来", "下来", "上来",
      "进来", "出来", "回来", "过来", "下去",
      "上去", "进去", "出去", "回去", "过去",
    }

    # Kiểm tra động từ ly hợp
    def self.liheci?(verb : String, obj : String) : Bool
      LIHECI.includes?(verb + obj)
    end

    # Kiểm tra phương vị từ
    def self.localizer?(text : String) : Bool
      LOCALIZERS.includes?(text)
    end

    # Kiểm tra bổ ngữ xu hướng
    def self.direction_complement?(text : String) : Bool
      DIRECTION_COMPLEMENTS.includes?(text)
    end

    # Process a tree with dependency-based rules (post-order traversal)
    def self.process(node : Node) : Node
      # Recursive processing for children
      node.children = node.children.map { |c| process(c) }

      # Apply rules based on this node's children's deprels
      # Find children that trigger structural changes
      # Note: We iterate a copy or index because children array might change

      # We look for specific patterns in children
      if node.children.any? { |c| c.deprel == "ba" }
        process_ba(node)
      elsif node.children.any? { |c| c.deprel == "pass" || c.token.try(&.pos) == "LB" }
        process_bei(node)
      elsif node.children.any? { |c| c.deprel == "loc" || c.deprel == "lobj" || c.deprel == "plmod" }
        process_localizer(node)
      else
        node
      end
    end

    # ===== Xử lý cụ thể cho từng deprel =====

    # Xử lý 把 construction: S + 把 + O + V → S + V + O
    def self.process_ba(node : Node) : Node
      # Node is the VP containing BA and the rest
      # Children: [BA, IP/VP(object+verb)] or [BA, Object, Verb]

      ba_child = node.children.find { |c| c.deprel == "ba" }
      return node unless ba_child

      # 1. Clear "把" translation
      ba_child.vietnamese = ""

      # 2. Find the Object
      # Case A: Object is inside BA (unlikely in CTB but possible in dependency view)
      # Case B: Object is a sibling of BA (standard CTB: VP -> BA + IP/VP)
      # In the fixture: VP -> BA + IP. Inside IP is NP(Object) + VP(Verb)

      # Let's try to handle the standard CTB structure where BA is followed by an IP/VP
      # and that IP/VP contains the object and the verb.
      # Actually, the 'ba' transform in dependency trees (SD) usually implies:
      # O is the dependent of 'ba' (or ba is dependent of V, and O is dependent of V with 'ba' relation? No, ba is usually aux/case)
      # In our RawCon->Node tree, we rely on the structure.

      # Find the clause following BA
      clause_idx = node.children.index(ba_child).not_nil! + 1
      clause = node.children[clause_idx]?

      return node unless clause

      # If the clause is an IP (common), it might contain [NP(Obj), VP(Verb)]
      # We want to transform: BA + [Obj, Verb] -> [Verb, Obj]

      # Check if clause has [NP, VP] or similar structure
      if clause.children.size >= 2
        # Assume first child is Object, second is Verb(phrase)
        obj = clause.children[0]
        verb_part = clause.children[1]

        # In Vietnamese: V + O
        # But if Verb(phrase) has aspect markers or complements, O should often come right after the verb.
        # e.g., "ăn táo rồi" (Verb + Obj + Particle)

        # Check if verb_part is a phrase with multiple children (e.g., [VV, AS], [VV, PP])
        if verb_part.phrase? && verb_part.children.size >= 2
          # Find the verb node index
          v_idx = verb_part.children.index { |c| c.label.starts_with?("V") || c.token.try(&.pos).try(&.starts_with?("V")) }
          if v_idx
            # Insert Obj right after the verb inside the phrase
            verb_part.children.insert(v_idx + 1, obj)
            # Remove Obj from Clause
            clause.children.delete_at(0)
          else
            # Fallback: swap them [Obj, Verb] -> [Verb, Obj]
            clause.children = [verb_part, obj] + clause.children[2..-1]
          end
        elsif verb_part.leaf? || verb_part.children.size < 2
          # If it's a single verb token "看完", we might need to separate it if it has an internal complement
          # But for now, just swap: [Obj, Verb] -> [Verb, Obj]
          clause.children = [verb_part, obj] + clause.children[2..-1]
        end
      end

      node
    end

    # Xử lý 被 passive: S + 被 + V → S + bị/được + V
    def self.process_bei(node : Node, sentiment : Symbol = :neutral) : Node
      # Tìm child có deprel = "pass" hoặc là LB (từ loại 被)
      pass_child = node.children.find { |c| c.deprel == "pass" || c.token.try(&.pos) == "LB" }
      return node unless pass_child

      # Chọn "bị" hoặc "được" dựa trên sentiment
      pass_child.vietnamese = case sentiment
                              when :negative then "bị"
                              when :positive then "được"
                              else                "bị" # Default to "bị" for neutral/negative contexts usually
                              end

      # Handle aspect markers (AS) if present in the VP (usually at end)
      # If we find 'Le' (了), we often want to move it before 'Bei' as 'đã'
      # S + 被 + Agent + V + 了 -> S + đã + bị + Agent + V

      # Let's simplify: if we see '了' in the subtree, move it to front of 'Bei' as 'đã'
      le_node = node.find_node do |n|
        n.label == "AS" && (n.token.try(&.text) == "了" || n.token.try(&.pos) == "AS")
      end
      if target_le = le_node
        # Change translation to 'đã'
        target_le.vietnamese = "" # Clear old execution

        # Insert "đã" before pass_child
        da_token = Token.new("đã", "AD", nil, 0, "advmod")
        da_node = Node.leaf("AD", da_token, -1)
        da_node.vietnamese = "đã"

        # Insert before pass_child
        # Note: pass_child must be in node.children
        pass_idx = node.children.index(pass_child)
        if pass_idx
          node.children.insert(pass_idx, da_node)
        end
      end

      node
    end

    # Xử lý phương vị từ: 在 + N + 上 → trên + N
    def self.process_localizer(node : Node) : Node
      # Tìm child có deprel = "loc" hoặc "lobj" hoặc "plmod"
      loc_child = node.children.find { |c| c.deprel == "loc" || c.deprel == "lobj" || c.deprel == "plmod" }
      return node unless loc_child

      loc_text = loc_child.token.try(&.text)
      target_for_vn = loc_child

      # Heuristic: if loc_child is a phrase (LCP), look for its LC child
      if !loc_text && loc_child.phrase?
        lc_node = loc_child.children.find { |c| c.token.try(&.pos) == "LC" || c.label == "LC" }
        if lc_node
          loc_text = lc_node.token.try(&.text)
          target_for_vn = lc_node
        end
      end

      return node unless loc_text && localizer?(loc_text)

      # Map phương vị từ
      vn_loc = case loc_text
               when "上"           then "trên"
               when "下"           then "dưới"
               when "里", "内", "中" then "trong"
               when "外"           then "ngoài"
               when "前"           then "trước"
               when "后"           then "sau"
               when "左"           then "bên trái"
               when "右"           then "bên phải"
               when "旁"           then "bên cạnh"
               else                    loc_text
               end

      target_for_vn.vietnamese = vn_loc

      # Đưa phương vị từ lên đầu TRONG LCP (桌子上 -> trên bàn)
      if target_for_vn != loc_child
        # Inside LCP: move LC to front
        others_in_lcp = loc_child.children.reject { |c| c == target_for_vn }
        loc_child.children = [target_for_vn] + others_in_lcp
        return node # Reordered inside LCP, don't move LCP itself to front of parent (PP/VP)
      end

      # If loc_child is a direct leaf of node (e.g. PP -> P, NP, LC)
      # Move it to front ONLY if parent is not a VP/PP (avoid 'ngồi trên bàn' -> 'trên bàn ngồi')
      unless node.label == "VP" || node.label == "PP"
        others = node.children.reject { |c| c == loc_child }
        node.children = [loc_child] + others
      end

      node
    end

    # Xử lý ly hợp: 吃饭 → ăn cơm (gộp hoặc xử lý đặc biệt)
    def self.process_liheci(verb_node : Node, obj_node : Node) : {Node, Bool}
      verb_text = verb_node.token.try(&.text) || ""
      obj_text = obj_node.token.try(&.text) || ""

      if liheci?(verb_text, obj_text)
        # Đánh dấu là ly hợp - cần tra từ điển với key đặc biệt
        {verb_node, true}
      else
        {verb_node, false}
      end
    end
  end
end
