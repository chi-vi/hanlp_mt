require "../node"

module Zh2Vi
  module Rules
    module AdvbRules
      # Using a set for faster lookups
      # Added "最" (nhất) to the list of adverbs that should be moved after the verb/adjective
      SPECIAL_POST_ADVERBS = Set.new(["这么", "非常", "好好", "十分", "最"])

      def self.process(node : Node) : Node
        # Process children first (bottom-up)
        # We need to process children recursively
        new_children = node.children.map { |c| process(c) }
        node.children = new_children

        # Apply translation logic if it's a leaf node
        if node.leaf?
          apply_translation_rule(node)
        end

        # Structural changes (Reordering) - only apply to VP/AP/IP/ADJP nodes likely to contain modifiers
        # Based on fixture: IP -> VP -> ADVP + VP.
        # Also ADJP -> ADVP + ADJP (e.g. 最高的楼)
        if node.label.starts_with?("VP") || node.label.starts_with?("AP") || node.label == "IP" || node.label == "ADJP"
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
        # Look for [ADVP, VP/VA/VV/ADJP] pattern where ADVP contains special adverbs
        # We want to swap them: [VP/VA/VV/ADJP, ADVP]
        # Also look for [DVP, VP] pattern (Manner adverbial) -> [VP, DVP]

        children = node.children
        # We modify the array in place.

        i = 0
        while i < children.size - 1
          current = children[i]
          next_node = children[i + 1]

          # Case 1: ADVP + Verbal/Adjectival (Superlatives/Special Adverbs)
          if current.label == "ADVP" && contains_special_adverb?(current)
            if is_verbal_or_adjectival?(next_node)
              # Swap: [next_node, current]
              children[i] = next_node
              children[i + 1] = current
              i += 2
              next
            end
          end

          # Case 2: DVP + VP (Manner adverbial: "happily play" -> "play happily")
          # DVP is usually marked with "地" (DEV) inside
          if current.label == "DVP" && next_node.label == "VP"
            # Swap: [next_node, current]
            children[i] = next_node
            children[i + 1] = current

            # Clear "地" (mà) translation because it's awkward at the end
            clear_dev_translation(current)

            i += 2
            next
          end

          i += 1
        end

        node.children = children
      end

      private def self.clear_dev_translation(dvp_node : Node)
        # Find DEV and clear its leaves' Vietnamese translation
        dvp_node.children.each do |child|
          if child.label == "DEV" || child.token.try(&.pos) == "DEV"
            child.leaves.each { |leaf| leaf.vietnamese = "" }
          elsif child.children.size > 0
            # Recurse if needed (though DEV is usually direct child of DVP)
            clear_dev_translation(child)
          end
        end
      end

      private def self.contains_special_adverb?(advp_node : Node) : Bool
        # Check if any leaf text is in our special set
        advp_node.leaves.any? do |leaf|
          text = leaf.token.try(&.text)
          text && SPECIAL_POST_ADVERBS.includes?(text)
        end
      end

      private def self.is_verbal_or_adjectival?(node : Node) : Bool
        # Check label (VP, AP, IP, ADJP, etc.)
        return true if node.label.starts_with?("VP")
        return true if node.label.starts_with?("AP")
        return true if node.label.starts_with?("ADJP")
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
