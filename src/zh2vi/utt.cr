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
      when "PERSON" then "NR"
      when "ORG", "PRODUCT", "EVENT", "WORK_OF_ART",
           "LAW", "FACILITY", "NORP", "GPE", "LOCATION",
           "DATE", "TIME" then "N"
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
    # NR/PN/M → N, A ↔ V, then X
    FALLBACK_CHAIN = {
      "NR" => ["N", "X"],
      "PN" => ["N", "X"],
      "M"  => ["N", "X"],
      "A"  => ["V", "X"],
      "V"  => ["A", "X"],
      "N"  => ["X"],
      "D"  => ["X"],
      "I"  => ["X"],
      "F"  => ["X"],
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
