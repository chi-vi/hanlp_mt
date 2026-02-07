# DRT - Dependency Relation Tags
# Bộ nhãn tối giản dùng cho dep-dict để tra nghĩa theo cặp từ phụ thuộc
# See: doc/deprel-tagset.md
#
# LƯU Ý: DRT chỉ dùng để tra từ điển (dictionary lookup)
# Các quy luật ngữ pháp (đảo vị trí, biến đổi cấu trúc) sử dụng
# trực tiếp deprel gốc từ SD-Chinese (xem: doc/annotations/dep-sd_zh.md)

module Zh2Vi
  module DRT
    # 8 DRT tags - chỉ dùng cho dictionary lookup
    TAGS = %w[OBJ RES NMOD CLF ADV PREP BEI OTH]

    # Mapping từ deprel (HanLP SD) sang DRT
    # Chỉ map những quan hệ có thể thay đổi nghĩa từ
    def self.from_deprel(deprel : String) : String
      case deprel
      # Tân ngữ: V → N
      when "dobj", "range", "attr"
        "OBJ"
        # Bổ ngữ kết quả: V → V/A
      when "rcomp"
        "RES"
        # Định ngữ: M → N
      when "nn", "amod", "assmod", "rcmod"
        "NMOD"
        # Lượng từ: CLF → N
      when "clf", "nummod", "ordmod"
        "CLF"
        # Trạng ngữ: ADV → V
      when "advmod", "tmod", "dvpmod", "dvpm", "mmod"
        "ADV"
        # Giới từ: P → N/V
      when "prep", "pobj", "lobj", "pccomp", "loc"
        "PREP"
        # Thể bị động
      when "pass", "nsubjpass"
        "BEI"
      else
        # Fallback cho tất cả trường hợp khác
        "OTH"
      end
    end
  end
end
