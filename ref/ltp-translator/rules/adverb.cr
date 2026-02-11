require "../node"
require "../pos_tag"

module QTran
  module AdverbRules
    extend self

    def apply(nodes : Array(MtNode)) : Array(MtNode)
      new_nodes = [] of MtNode
      i = 0

      while i < nodes.size
        # Helper: Check if Meiyou is nearby before (Logic for CompareRules conflict)
        # CompareRules Pattern: [Meiyou] [Noun] [Zheme] [Adj]
        # So "Zheme" is at index `i`. Nodes[i-1] is Noun. Nodes[i-2] is Meiyou.
        is_meiyou_context = false
        if (check_zheme = nodes[i]?) && (check_zheme.key == "这么" || check_zheme.key == "那么")
          # Check i-1 (Noun/Pronoun)
          if i > 0 && ((n = nodes[i - 1]?) && (n.noun? || n.pronoun?))
            # Check i-2 (Meiyou)
            if i > 1 && ((m = nodes[i - 2]?) && (m.key == "没有" || m.key == "没"))
              is_meiyou_context = true
            end
          end
          # Debug print
          # puts "AdverbRules: Check Zheme at #{i}. Context: #{is_meiyou_context}. Prev: #{nodes[i - 1].key rescue nil}, PrevPrev: #{nodes[i - 2].key rescue nil}"
        end

        if (adv = nodes[i]) && (adv.adverb? || adv.tag == PosTag::Number || adv.pronoun?)
          key = adv.key
          # Target Adverbs
          if key == "最" || key == "最为" ||
             key == "这么" || key == "那么" || key == "如此" ||
             key == "非常" || key == "十分" || key == "好好" ||
             key == "很"
            if is_meiyou_context
              new_nodes << nodes[i]
              i += 1
              next
            end

            # Check for Head (Adj or Verb)
            idx_head = i + 1
            if (head = nodes[idx_head]?) && (head.adj? || head.verb?)
              parent = MtNode.new("", head.tag) # Inherit head tag

              # Value Mapping
              case key
              when "最", "最为"  then adv.val = "nhất"
              when "这么"       then adv.val = "như thế này"
              when "那么", "如此" then adv.val = "như thế đó"
              when "非常"       then adv.val = "vô cùng"
              when "好好"       then adv.val = "cho tốt"
              when "十分"       then adv.val = "mười phần"
              when "很"        then adv.val = "rất"
              end

              # Output logic: Swap or Keep?
              # "Hen" (Rat) keeps order: "Rat Tot"
              # Others swap: "Tot Nhat", "Tot Vo Cung"
              if key == "很"
                parent.children << adv
                parent.children << head
              else
                parent.children << head
                parent.children << adv
              end

              new_nodes << parent
              i += 2
              next
            end
          end
        end

        new_nodes << nodes[i]
        i += 1
      end

      new_nodes
    end
  end
end
