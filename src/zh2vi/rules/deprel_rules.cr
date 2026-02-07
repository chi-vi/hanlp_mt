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

    # ===== Xử lý cụ thể cho từng deprel =====

    # Xử lý 把 construction: S + 把 + O + V → S + V + O
    def self.process_ba(node : Node) : Node
      # Tìm child có deprel = "ba"
      ba_child = node.children.find { |c| c.deprel == "ba" }
      return node unless ba_child

      # Xóa 把 (không dịch)
      ba_child.vietnamese = ""

      # Tìm tân ngữ (thường là child của 把)
      obj = ba_child.children.find { |c| c.deprel == "dobj" || c.deprel == "pobj" }
      return node unless obj

      # Đảo: đưa tân ngữ ra sau động từ chính
      # (Logic cụ thể phụ thuộc vào cấu trúc cây)
      node
    end

    # Xử lý 被 passive: S + 被 + V → S + bị/được + V
    def self.process_bei(node : Node, sentiment : Symbol = :neutral) : Node
      # Tìm child có deprel = "pass"
      pass_child = node.children.find { |c| c.deprel == "pass" }
      return node unless pass_child

      # Chọn "bị" hoặc "được" dựa trên sentiment
      pass_child.vietnamese = case sentiment
                              when :negative then "bị"
                              when :positive then "được"
                              else                "được"
                              end

      node
    end

    # Xử lý phương vị từ: 在 + N + 上 → trên + N
    def self.process_localizer(node : Node) : Node
      # Tìm child có deprel = "loc" hoặc "lobj"
      loc_child = node.children.find { |c| c.deprel == "loc" || c.deprel == "lobj" }
      return node unless loc_child

      loc_text = loc_child.token.try(&.text)
      return node unless loc_text && localizer?(loc_text)

      # Map phương vị từ
      loc_child.vietnamese = case loc_text
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

      # Đưa phương vị từ lên đầu
      others = node.children.reject { |c| c == loc_child }
      node.children = [loc_child] + others

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
