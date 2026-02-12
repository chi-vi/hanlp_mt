require "../node"

module Zh2Vi::Rules
  # Reorder module contains rules for transforming Chinese tree structure
  # to Vietnamese word order
  module Reorder
    # Process a tree with all reordering rules (post-order traversal)
    def self.process(node : Node, dict : Dict::PosDict? = nil) : Node
      result = node.dup

      # Post-order: process children first, then this node
      result.children = result.children.map { |c| process(c, dict) }

      # Skip atomic nodes (NER entities)
      return result if result.is_atomic?

      # Apply reordering rules based on label
      case result.label
      when "NP", "IP"
        # Treat IP like NP because HanLP sometimes labels NPs as IPs (e.g. "This book I bought")
        reorder_np(result)
      when "DNP"
        reorder_dnp(result)
      when "LCP"
        reorder_lcp(result)
      when "CP"
        reorder_cp(result)
      when "VP"
        process_vp(result, dict)
      when "QP"
        reorder_qp(result)
      when "DP"
        reorder_dp(result)
      else
        result
      end
    end

    # NP reordering: Chinese modifier-head -> Vietnamese head-modifier
    # Examples:
    # - 漂亮的книга -> sách đẹp
    # - DT + M + N -> N + M + DT (demonstratives to end)
    def self.reorder_np(node : Node) : Node
      return node if node.children.size < 2

      # Guard: If IP is a sentence or Topic-Object, don't reorder as NP
      if node.label == "IP"
        if restructured = restructure_relative_ip(node)
          return restructured
        end
        return node if is_sentence?(node) || is_topic_object?(node)
      end

      # Guard: If NP contains conjunctions (CC) or list punctuation (PU + 、), don't reorder as simple NP
      if is_list_or_conjunction?(node)
        return node
      end

      # Assume right-headedness for Chinese NP
      head = node.children.last
      modifiers = node.children[0...-1]

      # Exception: if last child is ETC (等/等等), treat as head but don't reorder the rest as modifiers
      if head.label == "ETC" || head.leaves.first?.try(&.token).try(&.pos) == "ETC"
        return node
      end

      pre_modifiers = [] of Node
      post_modifiers = [] of Node
      tail_modifiers = [] of Node # For DT/Demonstratives at the very end

      modifiers.each do |mod|
        pos = mod.token.try(&.pos) || mod.label

        if pos == "DP"
          # Unpack DP: DT goes to tail, others (QP/CLP) stay in pre
          # DP -> [DT, QP, CLP]
          dt_nodes = [] of Node
          other_nodes = [] of Node

          mod.children.each do |c|
            c_pos = c.token.try(&.pos) || c.label
            if c_pos == "DT"
              dt_nodes << c
            else
              other_nodes << c
            end
          end

          tail_modifiers.concat(dt_nodes)
          pre_modifiers.concat(other_nodes)
        elsif pos == "DT"
          tail_modifiers << mod
        elsif {"ADJP", "CP", "DNP", "JJ", "VA", "PP"}.includes?(pos)
          post_modifiers << mod
        elsif {"QP", "CLP", "M"}.includes?(pos)
          pre_modifiers << mod
        elsif pos == "NN" || pos == "NR" || pos == "NP" || pos == "PN"
          # Noun modifier (N + N) -> N + N (friends dad)
          # Vietnamese: dad of friend (bố (của) bạn)
          # So Noun modifier should be POST head.
          # BUT if head is VP (IP structure), NP/PN is Subject -> PRE head.
          # OR if it's a Topic-Object structure: 他 (Subj) 苹果 (Obj) 吃掉了 (Verb)
          # We check if head is a VP that already has a subject or if it's a specific pattern.
          if head.label == "VP" || head.label == "IP"
            pre_modifiers << mod
          else
            post_modifiers << mod
          end
        else
          # Default: keep before head
          pre_modifiers << mod
        end
      end

      # Construct new order: Pre + Head + Post + Tail
      node.children = pre_modifiers + [head] + post_modifiers + tail_modifiers
      node
    end

    # Detect and restructure IP that is actually a relative clause
    # IP -> [NP(Subj), VP(VV, AS(De), NP(Obj))]
    # Target: Obj + Subj + VV (Sách tôi mua)
    private def self.restructure_relative_ip(node : Node) : Node?
      # Check structure
      return nil unless node.children.size == 2

      subj = node.children[0]
      vp = node.children[1]

      return nil unless (subj.label == "NP" || subj.label == "PN") && vp.label == "VP"

      # Check VP internals
      # Expect [VV, AS, NP] or similar where AS is "的"
      vv = vp.children.find { |c| c.label.starts_with?("V") }
      as_node = vp.children.find { |c| c.token.try(&.pos) == "AS" || c.token.try(&.pos) == "DEC" }
      obj = vp.children.find { |c| c.label == "NP" }

      return nil unless vv && as_node && obj

      # Check if AS matches "的"
      as_text = as_node.token.try(&.text)
      return nil unless as_text == "的"

      # Confirmed pattern. Restructure.
      # We want [Obj, Subj, VV]

      # We can't easily move Obj out of VP in the tree structure cleanly without duping/reparenting logic which Node doesn't strictly enforce but traverse might expect.
      # But strictly for traversal output order:
      # If we set node.children = [obj, subj, vv]
      # obj and vv are detached from their parents.
      # Since we are in post-order traversal, obj and vv handles are already processed/translated?
      # Yes.
      # So simple re-assignment is fine for output.

      node.children = [obj, subj, vv]
      return node
    end

    # DNP reordering: Possessor + DEG + Noun -> Noun + của + Possessor
    # 老师的书 -> sách của thầy giáo
    def self.reorder_dnp(node : Node) : Node
      return node if node.children.size < 2

      # Find DEG node
      deg_idx = node.children.index { |c| c.token.try(&.pos) == "DEG" || c.label == "DEG" }
      return node unless deg_idx

      # Everything before DEG is possessor, DEG is connector
      possessor = node.children[0...deg_idx]
      deg = node.children[deg_idx]

      # Set Vietnamese for DEG if not already set (e.g. by AttrRules)
      deg.vietnamese ||= "của"

      # Reorder: DEG + Possessor
      # Chinese: Possessor + DEG (我 + 的)
      # Vietnamese: DEG + Possessor (của + tôi)
      node.children = [deg] + possessor
      node
    end

    # LCP reordering: NP + LC -> LC + NP (localizer phrase)
    # 桌子上 -> trên bàn
    def self.reorder_lcp(node : Node) : Node
      return node if node.children.size < 2

      # Find LC (localizer) - usually last child
      lc_idx = node.children.index { |c| c.token.try(&.pos) == "LC" || c.label == "LC" }
      return node unless lc_idx

      # Get the localizer and the rest
      lc = node.children[lc_idx]
      others = node.children.map_with_index { |c, i| i != lc_idx ? c : nil }.compact

      # Move LC to front
      node.children = [lc] + others
      node
    end

    # CP reordering: Relative clause + DEC + Head NP -> Head NP + mà + Clause
    # 我买的书 -> sách mà tôi mua
    def self.reorder_cp(node : Node) : Node
      return node if node.children.size < 2

      # Find DEC node
      dec_idx = node.children.index { |c| c.token.try(&.pos) == "DEC" || c.label == "DEC" }

      if dec_idx
        dec = node.children[dec_idx]
        dec.vietnamese ||= "mà"
      end

      # The actual reordering (CP before NP -> NP before CP) happens at parent level
      node
    end

    # VP processing: handle aspect markers, PP movement
    def self.process_vp(node : Node, dict : Dict::PosDict? = nil) : Node
      # Handle aspect markers (了, 着, 过) - move to front as adverbs
      process_aspect_markers(node, dict)

      # Handle QP modifier reordering (QP + VP -> VP + QP)
      reorder_modifier_qp(node)

      # Handle PP movement (PP before V -> V before PP)
      move_pp_to_end(node)

      node
    end

    # Move aspect markers (AS) to front of VP as adverbs OR keep at end based on translation
    # V + 了 -> đã + V (if translated as 'đã')
    # V + 了 -> V + rồi (if translated as 'rồi')
    private def self.process_aspect_markers(node : Node, dict : Dict::PosDict? = nil) : Node
      as_idx = node.children.index { |c| c.token.try(&.pos) == "AS" }
      return node unless as_idx

      as_node = node.children[as_idx]
      as_text = as_node.token.try(&.text)
      return node unless as_text

      # 1. Check if translation is already set (by CompRules)
      if vn_adv = as_node.vietnamese
        # Use existing translation
        if vn_adv == "rồi"
          placement = :back
        else
          placement = :front
        end
      elsif dict
        # Try lookup
        if vn_adv = dict.lookup(as_text, "AS")
          # Heuristic: 'rồi' -> back, 'đã'/'đang' -> front
          if vn_adv == "rồi"
            placement = :back
          else
            placement = :front
          end

          # We can set the translation here to ensure consistency
          as_node.vietnamese = vn_adv
        end
      end

      # 2. Fallback to hardcoded rules if no dict match or no dict provided
      unless vn_adv
        vn_adv = case as_text
                 when "了" then "đã"
                 when "着" then "đang"
                 when "过" then "đã từng"
                 else          nil
                 end
        placement = :front
        as_node.vietnamese = vn_adv if vn_adv
      end

      return node unless vn_adv

      # Remove AS from current position
      others = node.children.map_with_index { |c, i| i != as_idx ? c : nil }.compact

      if placement == :front
        # Find verb position and insert before it
        verb_idx = others.index { |c|
          pos = c.token.try(&.pos) || c.label
          pos.starts_with?("V")
        }

        if verb_idx
          node.children = others[0...verb_idx] + [as_node] + others[verb_idx..]
        else
          node.children = [as_node] + others
        end
      else
        # Placement :back - move to end
        node.children = others + [as_node]
      end

      node
    end

    # Move PP (prepositional phrase) to after VP
    # PP + V -> V + PP
    private def self.move_pp_to_end(node : Node) : Node
      # Find PP that should be moved (location/instrument PPs)
      pp_indices = [] of Int32
      node.children.each_with_index do |child, i|
        if child.label == "PP"
          # Check if it's a location PP (在, 于, 往, 向, 自)
          first_leaf = child.leaves.first?
          if first_leaf
            prep = first_leaf.token.try(&.text)
            if prep && {"在", "于", "往", "向", "自"}.includes?(prep)
              pp_indices << i
            end
          end
        end
      end

      return node if pp_indices.empty?

      # Collect PPs to move
      pps_to_move = pp_indices.map { |i| node.children[i] }

      # Remove PPs from current positions
      remaining = node.children.map_with_index { |c, i| !pp_indices.includes?(i) ? c : nil }.compact

      # Append PPs at the end
      node.children = remaining + pps_to_move
      node
    end

    # QP reordering: Handle demonstrative in quantity phrases
    # 这三本书 -> ba cuốn sách này
    def self.reorder_qp(node : Node) : Node
      # Check for DT at beginning
      dt_idx = node.children.index { |c| c.token.try(&.pos) == "DT" }
      return node unless dt_idx && dt_idx == 0

      # Move DT to end
      dt = node.children[0]
      rest = node.children[1..]
      node.children = rest + [dt]
      node
    end

    # QP modifier reordering: QP + VP -> VP + QP
    # Five feet tall -> Tall five feet
    # 五尺 (QP) + 高 (VP/VA) -> 高 (VP/VA) + 五尺 (QP)
    def self.reorder_modifier_qp(node : Node) : Node
      return node if node.children.size != 2

      left, right = node.children[0], node.children[1]

      # Check for QP + VP pattern
      if left.label == "QP" && right.label == "VP"
        node.children = [right, left]
        return node
      end

      node
    end

    # DP reordering: Demonstrative + Classifier -> Classifier + Demonstrative
    # 这本 -> quyển này
    def self.reorder_dp(node : Node) : Node
      return node if node.children.size < 2

      # Force CLP/M/QP to be before DT (Demonstrative)
      # [DT, CLP] -> [CLP, DT]
      # Scan children for DT and CLP
      dt_node = node.children.find { |c| c.label == "DT" || c.token.try(&.pos) == "DT" }
      clp_node = node.children.find { |c| c.label == "CLP" || c.label == "M" || c.token.try(&.pos) == "M" || c.label == "QP" }

      if dt_node && clp_node
        # Ensure CLP is before DT
        # Reconstruct children: CLP + DT + others
        others = node.children.reject { |c| c == dt_node || c == clp_node }
        node.children = [clp_node, dt_node] + others
      end

      node
    end

    private def self.is_sentence?(node : Node) : Bool
      return false if node.children.size < 2
      first = node.children.first

      # Starts with CP/ADVP/CS
      return true if first.label == "CP" || first.label == "ADVP" || first.label == "CS" || first.label == "PP"

      # Subj + VP
      has_vp = node.children.any? { |c| c.label == "VP" }
      (first.label == "NP" || first.label == "PN") && has_vp
    end

    private def self.is_topic_object?(node : Node) : Bool
      # Pattern: Subj(NP/PN) + Obj(NP/PN) + VP
      return false if node.children.size < 3
      c1, c2, c3 = node.children[0], node.children[1], node.children[2]
      (c1.label == "NP" || c1.label == "PN") &&
        (c2.label == "NP" || c2.label == "PN") &&
        (c3.label == "VP")
    end

    private def self.is_list_or_conjunction?(node : Node) : Bool
      node.children.any? do |c|
        label = c.label
        text = c.leaves.first?.try(&.token).try(&.text)
        pos = c.leaves.first?.try(&.token).try(&.pos)

        label == "CC" || pos == "CC" ||
          text == "、" || text == "，" || text == "," ||
          label == "PU" && (text == "、" || text == "，")
      end
    end
  end
end
