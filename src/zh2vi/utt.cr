module Zh2Vi
  # UTT - Unified Translation Tagset
  # Minimal tagset for dictionary lookup, focusing on meaning differentiation
  module UTT
    # Map POS-CTB tag to UTT tag
    def self.from_pos(pos : String) : String
      case pos
      when "NN", "NT"       then "N"
      when "VV", "VA"       then "V"
      when "JJ"             then "A"
      when "AD"             then "D"
      when "P"              then "P"
      when "M", "CD", "OD"  then "M"
      when "NR"             then "NR"
      when "IJ", "ON", "SP" then "I"
      when "DEC", "DEG", "DER", "DEV", "AS", "MSP",
           "LC", "BA", "SB", "LB", "VC", "VE" then "F"
      else "X"
      end
    end

    # Map NER-OntoNotes tag to UTT tag
    def self.from_ner(ner : String) : String
      case ner
      when "PERSON", "NORP", "FACILITY", "ORGANIZATION",
           "GPE", "LOCATION", "PRODUCT", "EVENT",
           "WORK OF ART", "LAW" then "NR"
      when "DATE", "TIME" then "N"
      when "PERCENT", "MONEY", "QUANTITY",
           "ORDINAL", "CARDINAL" then "M"
      else "X"
      end
    end

    # Map CON-CTB phrase tag to UTT tag
    def self.from_con(con : String) : String
      case con
      when "NP", "NN"                                     then "N"
      when "VP", "VCD", "VCP", "VNV", "VPT", "VRD", "VSB" then "V"
      when "ADJP"                                         then "A"
      when "ADVP"                                         then "D"
      when "PP"                                           then "P"
      when "QP", "CLP"                                    then "M"
      when "INTJ"                                         then "I"
      when "DNP", "DVP", "LCP", "CP", "MSP"               then "F"
      else                                                     "X"
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

    # Fallback mapping for lookup: try base category if specific not found
    FALLBACKS = {
      "NR" => "N", # proper noun → noun
      "NT" => "N", # time noun → noun (via N already)
      "A"  => "V", # adjective → verb (similar meaning patterns)
      "D"  => "A", # adverb → adjective
    }

    def self.fallback(utt : String) : String?
      FALLBACKS[utt]?
    end
  end
end
