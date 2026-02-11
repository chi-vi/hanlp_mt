require "../node"
require "../pos_tag"

module QTran
  module DeterminerRules
    extend self

    def apply(nodes : Array(MtNode)) : Array(MtNode)
      new_nodes = [] of MtNode
      i = 0

      while i < nodes.size
        # 1. Determiner Post-posing: [Det] [(Num)] [Cls] [Noun/Group] -> [(Num)][Cls][Noun] [Det]
        # Det: Zhe (This), Na (That), Gai (The/Said)
        if (det = nodes[i]) && (det.key == "这" || det.key == "那" || det.key == "该") && det.pronoun?
          # Lookahead for Classifier group
          # Pattern 1: [Det] [Num] [Cls] [Noun]
          # Pattern 2: [Det] [Cls] [Noun]

          head_group = [] of MtNode
          idx_curr = i + 1

          # Check Optional Number
          if (num = nodes[idx_curr]?) && num.tag == PosTag::Number
            head_group << num
            idx_curr += 1
          end

          # Check Essential Classifier
          if (cls = nodes[idx_curr]?) && (cls.tag == PosTag::Quant || cls.tag == PosTag::Noun) # Sometimes Cls is N
            # Ideally check if it IS a classifier. 'Ben', 'Ge', etc.
            # Let's assume strict structure Det/Num -> Cls

            head_group << cls
            idx_curr += 1

            # Check Essential Head Noun (or Noun Group)
            if (noun = nodes[idx_curr]?) && (noun.noun? || noun.pronoun?)
              head_group << noun
              idx_curr += 1

              # Create Parent Node
              parent = MtNode.new("", PosTag::Noun)

              # Value Mapping
              case det.key
              when "这" then det.val = "này"
              when "那" then det.val = "đó" # or kia
              when "该" then det.val = ""   # 'Cai ... do'? Usually 'gai' means 'that/the'.
              end

              # Output: HeadGroup + Det
              head_group.each { |n| parent.children << n }
              unless det.val.empty?
                parent.children << det
              end

              new_nodes << parent
              i = idx_curr # Skip consumed
              next
            end
          end

          # Fallback: [Det] [Noun] (Direct modification)
          # "Zhe Ren" -> "Nguoi Nay".
          # We must check idx_curr again because above checks might have advanced but failed at Noun step.
          # But if Number/Cls existed and Noun failed, we probably don't want to fallback to Det+Noun unless we backtrack.
          # Since we didn't advance 'i', we can check fallback.

          if (noun = nodes[i + 1]?) && (noun.noun? || noun.pronoun?)
            # Check if noun is NOT a Quantifier (ambiguity)
            # But if it was Quantifier, it would have been caught above (mostly).

            parent = MtNode.new("", PosTag::Noun)

            case det.key
            when "这" then det.val = "này"
            when "那" then det.val = "đó"
            end

            parent.children << noun
            parent.children << det

            new_nodes << parent
            i += 2
            next
          end
        end

        new_nodes << nodes[i]
        i += 1
      end

      new_nodes
    end
  end
end
