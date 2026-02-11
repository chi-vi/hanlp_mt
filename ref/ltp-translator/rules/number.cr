require "../node"
require "../pos_tag"

module QTran
  # Phase 0.2: Number Rules (Num + Quant + Noun -> Noun + Num + Quant)
  module NumberRules
    extend self

    def apply(nodes : Array(MtNode)) : Array(MtNode)
      new_nodes = [] of MtNode
      i = 0

      while i < nodes.size
        # 1. Num + [Quant] + Noun -> Noun + Num + [Quant]
        if (num = nodes[i]) && (num.tag == PosTag::Number)
          quant : MtNode? = nil
          noun : MtNode? = nil
          consumed = 1

          # Optional Quantifier
          if (nxt = nodes[i + 1]?) && nxt.tag == PosTag::Quant
            quant = nxt
            noun = nodes[i + 2]?
            consumed = 3
          else
            noun = nodes[i + 1]?
            consumed = 2
          end

          if noun && (noun.noun? || noun.tag == PosTag::NTime)
            parent = MtNode.new("", PosTag::Noun)

            # Logic: Drop 'Ge' (Cai) if Noun is Time
            if quant && quant.key == "个"
              if noun.tag == PosTag::NTime || noun.key == "小时" || noun.key == "钟头"
                quant.val = ""
              end
            end

            if quant
              if quant.val.empty?
                parent.children << num
                parent.children << noun
              else
                parent.children << num
                parent.children << quant
                parent.children << noun
              end
            else
              # Just Num + Noun
              parent.children << num
              parent.children << noun
            end

            new_nodes << parent
            i += consumed
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
