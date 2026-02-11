require "../node"

module Zh2Vi::Rules
  module AttrRules
    # Nouns that typically form direct compound words without "của" in Vietnamese
    # e.g., "bàn gỗ" (wooden table), "giá trị lịch sử" (historical value)
    DIRECT_ATTRIBUTE_NOUNS = Set.new(["木头", "历史", "价值", "文化", "经济", "科学", "社会"])

    def self.process(node : Node) : Node
      new_children = node.children.map { |c| process(c) }
      node.children = new_children

      if node.label == "DNP"
        process_dnp(node)
      elsif node.label == "CP"
        process_cp(node)
      end

      node
    end

    private def self.process_cp(node : Node)
      # CP Structure: [IP, DEC]
      # Drop DEC ("mà") for cleaner relative clauses unless complex?

      dec_idx = node.children.index { |c| c.label == "DEC" || c.token.try(&.pos) == "DEC" }
      return unless dec_idx

      dec_node = node.children[dec_idx]

      # For now, always drop 'de' in CP to match expected output "sách tôi mua" (not "sách mà tôi mua")
      # "người ăn cơm" (not "người mà ăn cơm")
      dec_node.leaves.each do |leaf|
        leaf.vietnamese = ""
      end
    end

    private def self.process_dnp(node : Node)
      # DNP usually Structure: [Modifier (NP/QP), DEG (的)]

      # Find DEG node
      deg_idx = node.children.index { |c| c.label == "DEG" || c.token.try(&.pos) == "DEG" }
      return unless deg_idx && deg_idx > 0

      deg_node = node.children[deg_idx]
      modifier = node.children[deg_idx - 1]

      if should_drop_cua?(modifier)
        # We must set the translation on the LEAF node (the word "的"),
        # because the translator collects text from leaves.
        deg_node.leaves.each do |leaf|
          leaf.vietnamese = ""
        end
      end
    end

    private def self.should_drop_cua?(modifier : Node) : Bool
      # 1. Check for GPE (Geopolitical Entity) -> "Thủ đô Trung Quốc", "Người Việt Nam"
      if has_ner_gpe?(modifier)
        return true
      end

      # 2. Check for Direct Attribute Nouns (Material, Abstract concepts)
      # "Bàn gỗ", "Giá trị lịch sử"
      text = get_main_text(modifier)
      if text && DIRECT_ATTRIBUTE_NOUNS.includes?(text)
        return true
      end

      # 3. Check for Adjectival Modifiers (ADJP, JJ, VA)
      # "tòa nhà cao nhất", "cấu hình hàng đầu" -> drop "của"
      if is_adjectival?(modifier)
        return true
      end

      false
    end

    private def self.is_adjectival?(node : Node) : Bool
      # ADJP is adjective phrase
      return true if node.label.starts_with?("ADJP")

      # JJ/VA are adjective POS tags
      pos = node.token.try(&.pos) || node.label
      return true if pos == "JJ" || pos == "VA"

      false
    end

    private def self.has_ner_gpe?(node : Node) : Bool
      # Check if any leaf in the modifier hierarchy has GPE tag
      # Usually the modifier is just the GPE noun itself (NP -> NR -> China)
      node.leaves.any? do |leaf|
        leaf.token.try(&.ner) == "GPE"
      end
    end

    private def self.get_main_text(node : Node) : String?
      # Simple heuristic: flatten text.
      # For "木头", NP -> NN -> 木头.
      # If modifier is complex, this might be risky, but for single-word modifiers it's fine.
      node.leaves.map { |n| n.token.try(&.text) || "" }.join
    end
  end
end
