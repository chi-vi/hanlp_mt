module Zh2Vi
  # UTT - Unified Translation Tagset
  # Minimal tagset for dictionary lookup, focusing on meaning differentiation
  # See: doc/unified-tagset.md
  module UTT
    # Map POS-CTB tag to UTT tag
    def self.from_pos(pos : String) : String
      case pos
      when "NN", "NT"       then "N"
      when "VV", "VC", "VE" then "V"
      when "JJ", "VA"       then "A"
      when "AD"             then "D"
      when "M", "CD", "OD"  then "M"
      when "NR"             then "NR"
      when "PN", "DT"       then "PN"
      when "IJ", "ON", "SP" then "I"
      when "P", "BA", "SB", "LB", "DEC", "DEG", "DER",
           "DEV", "AS", "MSP", "LC", "ETC" then "F"
      else "X"
      end
    end

    # Map NER-OntoNotes tag to UTT tag
    def self.from_ner(ner : String) : String
      case ner
      when "PERSON", "ORG", "GPE", "LOCATION",
           "FACILITY", "NORP" then "NR"
      when "PRODUCT", "EVENT", "WORK_OF_ART",
           "LAW", "DATE", "TIME" then "N"
      when "PERCENT", "MONEY", "QUANTITY",
           "ORDINAL", "CARDINAL" then "M"
      else "X"
      end
    end

    # Map CON-CTB phrase tag to UTT tag
    def self.from_con(con : String) : String
      case con
      when "NP", "FRAG" then "N"
      when "VP", "IP", "CP", "VCD", "VCP", "VNV",
           "VPT", "VRD", "VSB" then "V"
      when "ADJP", "DNP", "UCP" then "A"
      when "ADVP", "DVP", "PP"  then "D"
      when "QP", "CLP"          then "M"
      when "DP"                 then "PN"
      when "INTJ"               then "I"
      when "LCP"                then "F"
      when "LST"                then "X"
      else                           "X"
      end
    end

    # Get UTT tag for a token, prioritizing NER if available
    def self.for_token(pos : String, ner : String? = nil) : String
      if ner && !ner.empty? && ner != "O"
        from_ner(ner)
      else
        from_pos(pos)
      end
    end

    # Fallback chain for dictionary lookup:
    # Mỗi tag có logic fallback riêng dựa trên đặc tính ngữ pháp
    FALLBACK_CHAIN = {
      # 1. Tên riêng: Nếu không thấy, tra như danh từ chung
      "NR" => ["N", "X"],

      # 2. Đại từ: Có tính chất danh từ
      "PN" => ["N", "X"],

      # 3. Số/Lượng từ: Đôi khi là danh từ đơn vị
      "M" => ["N", "X"],

      # 4. Tính từ:
      # - Tra V: Nhiều tính từ là động từ trạng thái (Stative Verbs)
      # - Tra D: Đôi khi từ điển lưu nó là phó từ
      "A" => ["V", "D", "X"],

      # 5. Động từ:
      # - Tra A: Động từ trạng thái/tâm lý
      # - Tra N: Danh động từ (vn) nhưng từ điển chỉ lưu gốc V
      "V" => ["A", "N", "X"],

      # 6. Danh từ:
      # - Tra V: Danh động từ (vn) nhưng từ điển chỉ có V
      # - Tra A: Danh tính từ (an) nhưng từ điển chỉ có A
      "N" => ["V", "A", "X"],

      # 7. Trạng từ: (Quan trọng - nhiều từ loại khác làm trạng từ)
      # - Tra A: Phó tính từ (ad) → tìm nghĩa gốc tính từ
      # - Tra V: Phó động từ (vd) → tìm nghĩa gốc động từ
      # - Tra M: Số/lượng từ làm trạng từ (一次, 再三)
      # - Tra N: Thời gian làm trạng từ (今天, 明年)
      "D" => ["A", "V", "M", "N", "X"],

      # 8. Hư từ:
      # - Tra V: Giới từ (p) thường có gốc là Động từ (在, 给, 对)
      # - Tra N: Phương vị từ (f) thường có gốc là Danh từ (上, 下, 前)
      "F" => ["V", "N", "X"],

      # 9. Thán từ:
      # - Tra V: Từ tượng thanh có thể là động từ kêu/hét
      # - Tra N: Từ tượng thanh có thể là danh từ tiếng động
      "I" => ["V", "N", "X"],

      # 10. Khác: Không có fallback
      "X" => [] of String,
    }

    # Get fallback tags for a UTT tag (returns array of fallbacks to try)
    def self.fallbacks(utt : String) : Array(String)
      FALLBACK_CHAIN[utt]? || ["X"]
    end

    # Legacy method for backward compatibility
    def self.fallback(utt : String) : String?
      fallbacks(utt).first?
    end
  end
end
