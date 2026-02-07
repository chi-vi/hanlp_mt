# DRT - Dependency Relation Tags
# Bộ nhãn tối giản dùng cho dep-dict để tra nghĩa theo cặp từ phụ thuộc
# See: doc/deprel-tagset.md
#
# LƯU Ý: DRT chỉ dùng để tra từ điển (dictionary lookup)
# Các quy luật ngữ pháp (đảo vị trí, biến đổi cấu trúc) sử dụng
# trực tiếp deprel gốc từ SD-Chinese (xem: doc/annotations/dep-sd_zh.md)

module Zh2Vi
  module DRT
    # 9 DRT tags - chỉ dùng cho dictionary lookup
    # Sắp xếp theo bias (ưu tiên tra cứu từ thấp → cao)
    TAGS = %w[RES OBJ AGT PREP ADV NMOD CLF BEI OTH]

    # Bias values - số nhỏ = ưu tiên cao hơn
    # Dùng để sắp xếp thứ tự tra cứu khi một từ có nhiều quan hệ
    BIAS = {
      "RES"  => 1, # Bổ ngữ KQ - thay đổi nghĩa động từ hoàn toàn
      "OBJ"  => 2, # Tân ngữ - phân biệt nghĩa theo tân ngữ
      "AGT"  => 3, # Chủ ngữ - đôi khi thay đổi nghĩa
      "PREP" => 4, # Giới từ - ngữ cảnh công cụ/địa điểm
      "ADV"  => 5, # Trạng ngữ - bổ sung mức độ/cách thức
      "NMOD" => 6, # Định ngữ - ít ảnh hưởng nghĩa gốc
      "CLF"  => 7, # Lượng từ - nghĩa tương đối cố định
      "BEI"  => 8, # Bị động - chỉ thêm bị/được
      "OTH"  => 9, # Fallback
    }

    # Mapping từ deprel (HanLP SD) sang DRT
    # Chỉ map những quan hệ có thể thay đổi nghĩa từ
    def self.from_deprel(deprel : String) : String
      case deprel
      # Chủ ngữ / Tác thể (bias=3)
      when "nsubj", "top", "xsubj", "csubj"
        "AGT"
        # Tân ngữ / Thụ thể (bias=2)
      when "dobj", "range", "attr", "ba", "nsubjpass"
        "OBJ"
        # Bổ ngữ kết quả (bias=1)
      when "rcomp", "ccomp", "xcomp"
        "RES"
        # Định ngữ danh từ (bias=6)
      when "nn", "amod", "assmod", "rcmod"
        "NMOD"
        # Lượng từ (bias=7)
      when "clf", "nummod", "ordmod", "det"
        "CLF"
        # Trạng ngữ (bias=5)
      when "advmod", "tmod", "dvpmod", "dvpm", "mmod", "neg"
        "ADV"
        # Giới từ (bias=4)
      when "prep", "pobj", "lobj", "pccomp", "loc", "lccomp", "plmod"
        "PREP"
        # Bị động marker (bias=8)
      when "pass"
        "BEI"
      else
        # Fallback (bias=9)
        "OTH"
      end
    end

    # Lấy bias của một DRT tag
    def self.bias(drt : String) : Int32
      BIAS[drt]? || 9
    end

    # So sánh ưu tiên: true nếu a có ưu tiên cao hơn b
    def self.higher_priority?(a : String, b : String) : Bool
      bias(a) < bias(b)
    end
  end
end
