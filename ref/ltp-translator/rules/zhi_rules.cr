require "../node"
require "../pos_tag"

module QTran
  module ZhiRules
    extend self

    # Apply rules for 之 (zhi) particle
    # Handles:
    # 1. 之一的 pattern (one of X)
    # 2. Possessive 之 (handled in dangling_zhi)
    def apply(nodes : Array(MtNode), new_nodes : Array(MtNode), i : Int32) : {Bool, Int32}
      # Pattern: X + 之 + 一 + 的 + Head → 一 + trong + X + Head
      # "清洁协会十二骑士之一的'收藏家'" → "một trong mười hai kỵ sĩ hiệp hội làm sạch '收藏家'"
      if (zhi = nodes[i]) && zhi.key == "之"
        if (yi = nodes[i + 1]?) && yi.key == "一"
          if (de = nodes[i + 2]?) && de.key == "的"
            # Found 之一的 pattern - need to grab preceding noun phrase and following head
            # Collect preceding nouns/adj from new_nodes (they've been accumulated)
            modifier_nodes = [] of MtNode
            while new_nodes.size > 0
              last = new_nodes.last
              if last.noun? || last.adj? || last.tag == PosTag::Number || last.tag == PosTag::Quant
                modifier_nodes << new_nodes.pop
              else
                break
              end
            end

            # Get head (next node after 的)
            head_idx = i + 3
            head = nodes[head_idx]?

            if head && modifier_nodes.size > 0
              parent = MtNode.new("", head.tag)

              # Output: 一 + trong + [modifier_nodes] + [head]
              yi.val = "một trong"
              parent.children << yi

              modifier_nodes.each { |m| parent.children << m }
              parent.children << head

              new_nodes << parent
              return {true, head_idx + 1}
            else
              # Fallback: restore modifier_nodes
              modifier_nodes.each { |m| new_nodes << m }
            end
          end
        end
      end

      {false, i}
    end

    # Check if 之 should be handled by dangling_zhi rule
    # Skip if this is part of 之一的 pattern
    def is_dangling_zhi?(nodes : Array(MtNode), i : Int32) : Bool
      de = nodes[i + 1]?
      return false unless de && de.key == "之"

      n1 = nodes[i]
      return false unless n1 && (n1.pronoun? || n1.noun?)

      # Skip if this is part of 之一的 pattern (handled separately)
      if (yi = nodes[i + 2]?) && yi.key == "一"
        return false
      end

      true
    end
  end
end
