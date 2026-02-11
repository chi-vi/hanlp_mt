require "../node"

module Zh2Vi::Rules
  module PrepRules
    # Process a tree with preposition-based rules (post-order traversal)
    def self.process(node : Node) : Node
      # Recursive processing for children first
      node.children = node.children.map { |c| process(c) }

      # Apply rules based on this node's children
      # We look for [PP, VP] pattern to swap to [VP, PP]

      # Handle specific preposition cases based on children content

      i = 0
      while i < node.children.size - 1
        current = node.children[i]
        next_node = node.children[i + 1]

        # general case: PP + VP -> VP + PP
        if is_pp?(current) && (is_vp?(next_node) || is_adjective?(next_node))
          # Check for specific prepositions that *should* be swapped
          # 1. 在 (zai) - Locative: 我在家里吃饭 -> tôi ăn cơm ở trong nhà
          # 2. 比 (bi) - Comparative: 我比你大 -> tôi lớn hơn bạn
          # 3. 给 (gei) - Dative/Benefactive: 我给你买书 -> tôi mua sách cho bạn (often)
          # 4. 跟 (gen) - Comitative: 我跟你去 -> tôi đi cùng bạn

          prep_token = get_prep_token(current)
          if prep_token
            pt = prep_token
            case pt
            when "在", "比", "给", "跟", "离"
              # Swap
              node.children[i] = next_node
              node.children[i + 1] = current

              # Post-processing for specific prepositions *after* swap if needed
              # e.g. "比" might need "hơn" added?
              # Actually "比" usually maps to "so với" or just "hơn" depending on context.
              # If we have [Adj] [PP(Bi)], "bạn lớn hơn tôi"
              # wait, "我比你大" -> "tôi" [bi ni] [da] -> swap -> "tôi" [da] [bi ni]
              # "tôi lớn so với k" -> "tôi lớn hơn bạn"
              # We might need to adjust the translation of 'bi' itself.

              if pt == "比"
                set_translation(current, "hơn")
              elsif pt == "离"
                # "我家离这儿很近" -> "nhà tôi cách đây rất gần"
                # "Li" maps to "cách".
                # Structure: [PP(Li zher)] [VP(very near)] -> [VP] [PP] ?
                # NO. "A 离 B 很近" -> "A cách B rất gần". Structure is preserved order-wise in Vietnamese for 'cach'.
                # "Nha toi" [cach day] [rat gan].
                # So "Li" should NOT be swapped?
                # Let's check fixture.
                # Case 6: "我家离这儿很近" -> "tôi nhà cách đây rất gần" ??? No "nhà tôi..."
                # If standard order is S + PP + V, and 离 behaves like a verb "cách",
                # then "A [Li B] [hen jin]" -> "A [cach B] [rat gan]".
                # So for 'Li', we do NOT swap.

                # Revert swap for 'Li'
                node.children[i] = current
                node.children[i + 1] = next_node
              end
            end
          end
        end
        i += 1
      end

      node
    end

    def self.is_pp?(node : Node) : Bool
      # Check if node is a Prepositional Phrase
      node.label == "PP"
    end

    def self.is_vp?(node : Node) : Bool
      # Check if node is a Verb Phrase
      node.label == "VP"
    end

    def self.is_adjective?(node : Node) : Bool
      # Check if node is an Adjective Phrase
      node.label == "ADJP" || node.label == "VA"
    end

    def self.get_prep_token(pp_node : Node) : String?
      # Find the P child
      p_node = pp_node.children.find { |c| c.label == "P" || c.token.try(&.pos) == "P" }
      p_node.try(&.token).try(&.text)
    end

    def self.set_translation(node : Node, text : String)
      # Find the P node and set its vietnamese translation
      target_node = nil
      node.traverse_preorder do |n|
        if target_node.nil? && (n.label == "P" || n.token.try(&.pos) == "P")
          target_node = n
        end
      end

      if t = target_node
        t.vietnamese = text
      end
    end
  end
end
