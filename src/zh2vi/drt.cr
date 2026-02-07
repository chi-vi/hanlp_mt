# DRT - Dependency Relation Tags
# Bộ nhãn dùng cho dep-dict để tra nghĩa từ theo cặp từ phụ thuộc
# See: doc/relation-tagset.md

module Zh2Vi
  module DRT
    # 18 DRT tags as defined in relation-tagset.md
    TAGS = %w[
      OBJ SEP PIV # Động từ
      SUBJ # Chủ ngữ
      RES DIR POT # Bổ ngữ
      NMOD POSS RMOD # Định ngữ
      TMOD ADV # Trạng ngữ
      LOC PREP BA BEI # Hư từ
      CLF COOR # Khác
    ]

    # Các quan hệ hư từ quan trọng - cần xử lý ưu tiên
    STRUCTURAL_RELATIONS = %w[BA BEI LOC]

    # Mapping từ deprel (HanLP SD) sang DRT
    # context được dùng để phân biệt các trường hợp đặc biệt
    def self.from_deprel(deprel : String, context : Context? = nil) : String?
      case deprel
      # Động từ
      when "dobj"
        context.try(&.liheci?) ? "SEP" : "OBJ"
      when "ccomp", "xcomp"
        "PIV"
        # Chủ ngữ
      when "nsubj", "top", "nsubjpass"
        "SUBJ"
        # Bổ ngữ
      when "rcomp"
        context.try(&.direction?) ? "DIR" : "RES"
      when "compound:dir", "attr"
        "DIR"
      when "mmod"
        "POT"
        # Định ngữ
      when "nn", "amod"
        "NMOD"
      when "assmod", "deg"
        "POSS"
      when "rcmod", "dec"
        "RMOD"
        # Trạng ngữ
      when "tmod"
        "TMOD"
      when "advmod", "dvp"
        "ADV"
        # Hư từ
      when "loc", "lobj"
        "LOC"
      when "prep", "pobj"
        "PREP"
      when "ba"
        "BA"
      when "agent", "pass"
        "BEI"
        # Khác
      when "clf"
        "CLF"
      when "cc", "conj"
        "COOR"
      else
        nil
      end
    end

    # Context cho việc xác định DRT
    struct Context
      getter? liheci : Bool    # Động từ ly hợp
      getter? direction : Bool # Bổ ngữ xu hướng

      def initialize(@liheci : Bool = false, @direction : Bool = false)
      end
    end

    # Danh sách động từ ly hợp thường gặp
    LIHECI = {
      "帮忙", "睡觉", "吃饭", "上班", "下班",
      "游泳", "跳舞", "唱歌", "跑步", "散步",
      "洗澡", "理发", "结婚", "离婚", "毕业",
      "见面", "打架", "吵架", "发烧", "生气",
    }

    # Phương vị từ thường gặp
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

    # Kiểm tra bổ ngữ xu hướng
    def self.direction?(complement : String) : Bool
      DIRECTION_COMPLEMENTS.includes?(complement)
    end

    # Kiểm tra phương vị từ
    def self.localizer?(text : String) : Bool
      LOCALIZERS.includes?(text)
    end

    # Xác định action dựa trên DRT
    enum Action
      Lookup    # Tra từ điển theo cặp
      Merge     # Gộp tokens (ly hợp)
      Reorder   # Đảo vị trí
      Transform # Biến đổi cấu trúc
      Skip      # Bỏ qua (đã xử lý ở parent)
    end

    def self.action_for(drt : String) : Action
      case drt
      when "OBJ", "RES", "DIR", "CLF"
        Action::Lookup
      when "SEP"
        Action::Merge
      when "NMOD", "POSS", "RMOD", "TMOD"
        Action::Reorder
      when "BA", "BEI", "LOC"
        Action::Transform
      else
        Action::Lookup
      end
    end

    # Hướng tra từ điển: Child→Parent hay Parent→Child
    enum LookupDirection
      ChildFirst  # Tra nghĩa dependent trước (OBJ, RES)
      ParentFirst # Tra nghĩa head trước (CLF)
    end

    def self.lookup_direction(drt : String) : LookupDirection
      case drt
      when "CLF"
        LookupDirection::ParentFirst
      else
        LookupDirection::ChildFirst
      end
    end
  end
end
