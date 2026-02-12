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
            when "在", "比", "给", "跟", "往", "向", "自", "从", "对"
              # Swap
              node.children[i] = next_node
              node.children[i + 1] = current

              # Post-processing for specific prepositions *after* swap
              case pt
              when "比"
                set_translation(current, "hơn")
              when "对"
                set_translation(current, "với")
                # when "向"
                #   set_translation(current, "về phía") # Context dependent, maybe leave to dictionary or specs
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
