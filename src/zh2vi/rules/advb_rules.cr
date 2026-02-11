require "../node"

module Zh2Vi
  module Rules
    module AdvbRules
      # Using a set for faster lookups
      SPECIAL_POST_ADVERBS = Set.new(["这么", "非常", "好好", "十分"])

      def self.process(node : Node) : Node
        # Process children first (bottom-up)
        # We need to process children recursively
        new_children = node.children.map { |c| process(c) }
        node.children = new_children

        # Apply translation logic if it's a leaf node
        if node.leaf?
          apply_translation_rule(node)
        end

        # Structural changes (Reordering) - only apply to VP/AP/IP nodes likely to contain modifiers
        # Based on fixture: IP -> VP -> ADVP + VP.
        # So we check parent VP.
        if node.label.starts_with?("VP") || node.label.starts_with?("AP") || node.label == "IP"
          process_reordering(node)
        end

        node
      end

      private def self.apply_translation_rule(node : Node)
        text = node.token.try(&.text)
        return unless text

        case text
        when "最好"
          # Only override if not already set (though usually empty)
          v = node.vietnamese
          node.vietnamese = "tốt nhất" if v.nil? || v.empty?
        end
      end

      private def self.process_reordering(node : Node)
        # Look for [ADVP, VP/VA/VV] pattern where ADVP contains special adverbs
        # We want to swap them: [VP/VA/VV, ADVP]

        children = node.children
        # We modify the array in place or build a new one.
        # Since we might swap, let's iterate with index carefully.

        i = 0
        while i < children.size - 1
          current = children[i]
          next_node = children[i + 1]

          if current.label == "ADVP" && contains_special_adverb?(current)
            if is_verbal_or_adjectival?(next_node)
              # Swap: [next_node, current]
              # Log logic: "Found special adverb #{current.leaves.map(&.token.try(&.text)).join}, swapping with #{next_node.label}"
              children[i] = next_node
              children[i + 1] = current

              # Advance past the swapped pair
              i += 2
              next
            end
          end
          i += 1
        end

        node.children = children
      end

      private def self.contains_special_adverb?(advp_node : Node) : Bool
        # Check if any leaf text is in our special set
        advp_node.leaves.any? do |leaf|
          text = leaf.token.try(&.text)
          text && SPECIAL_POST_ADVERBS.includes?(text)
        end
      end

      private def self.is_verbal_or_adjectival?(node : Node) : Bool
        # Check label (VP, AP, IP, etc.)
        return true if node.label.starts_with?("VP")
        return true if node.label.starts_with?("AP")
        # In fixture 2: VP -> [ADVP, VP]. So matching VP is correct.

        # Check POS if leaf or pre-terminal (VA, VV, JJ)
        # Sometimes structure is ADVP + VA directly?
        # Check fixture: VP -> VA (node). VA -> 好 (leaf).
        return true if node.label == "VA" || node.label == "VV" || node.label == "JJ"

        false
      end
    end
  end
end
