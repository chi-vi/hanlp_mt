require "../node"
require "../pos_tag"

module QTran
  module CompareRules
    extend self

    def apply(nodes : Array(MtNode)) : Array(MtNode)
      new_nodes = [] of MtNode
      i = 0

      while i < nodes.size
        # 1. A + Bi + B + (Adv) + Adj -> A + (Adv) + Adj + Hon + B
        if (bi = nodes[i]) && (bi.key == "比" || bi.key == "比较")
          idx_b = i + 1
          if (b_node = nodes[idx_b]?) && (b_node.noun? || b_node.pronoun?)
            # Look for Adj
            idx_adj = idx_b + 1
            adv_node : MtNode? = nil

            if (check = nodes[idx_adj]?) && check.adverb?
              adv_node = check
              idx_adj += 1
            end

            if (adj = nodes[idx_adj]?) && adj.adj?
              parent = MtNode.new("", PosTag::Adj)

              bi.val = "hơn"

              parent.children << adv_node if adv_node
              parent.children << adj
              parent.children << bi
              parent.children << b_node

              new_nodes << parent
              i = idx_adj + 1
              next
            end
          end
        end

        # 2. A + Meiyou + B + (Zheme/Name) + Adj -> A + Khong + Adj + Bang + B
        if (meiyou = nodes[i]) && (meiyou.key == "没有" || meiyou.key == "没")
          # Check if followed by Noun (B) + (Zheme/Name) + Adj
          idx_b = i + 1
          if (b_node = nodes[idx_b]?) && (b_node.noun? || b_node.pronoun?)
            idx_adj = idx_b + 1

            # Optional Zheme/Name (Consumed)
            zheme_skip = false
            if (check = nodes[idx_adj]?) && (check.key == "这么" || check.key == "那么")
              zheme_skip = true
              idx_adj += 1
            end

            if (adj = nodes[idx_adj]?) && adj.adj?
              # Lookahead for 'Xie' (Better) -> Existential usage, skip comparison
              # "Meiyou [Shenme] [Hao] [Xie]" -> "Don't have [anything] [better]"
              if (following = nodes[idx_adj + 1]?) && following.key == "些"
                new_nodes << nodes[i]
                i += 1
                next
              end

              parent = MtNode.new("", PosTag::Adj)

              meiyou.val = "không"
              bang = MtNode.new("bằng", PosTag::Rel, 0, "bằng")

              # Debug
              # puts "CompareRules: Matched Meiyou. B: #{b_node.key}, ZhemeSkip: #{zheme_skip}, Adj: #{adj.key}"
              # Check b_node children if any
              # puts "B Children: #{b_node.children.map(&.key).join(",")}" if b_node.children.any?

              # Output: Khong + Adj + Bang + B
              parent.children << meiyou
              parent.children << adj
              parent.children << bang
              parent.children << b_node

              new_nodes << parent
              i = idx_adj + 1
              next
            end
          end
        end

        # 3. Equative/Simile: (Gen/Xiang/Ru) + B + (Yiyang) + Adj -> (Adj) + Nhu/Giong + B
        if (prep = nodes[i]) && (prep.key == "跟" || prep.key == "和" || prep.key == "像" || prep.key == "如")
          idx_b = i + 1
          if (b_node = nodes[idx_b]?) && (b_node.noun? || b_node.pronoun?)
            idx_next = idx_b + 1

            # Optional Yiyang
            yiyang : MtNode? = nil
            if (check = nodes[idx_next]?) && (check.key == "一样" || check.key == "一般")
              yiyang = check
              idx_next += 1
            end

            # Adj
            if (adj = nodes[idx_next]?) && adj.adj?
              parent = MtNode.new("", PosTag::Adj)

              comparator = MtNode.new("như", PosTag::Compar, 0, "như")

              # Output: Adj + Nhu + B
              parent.children << adj
              parent.children << comparator
              parent.children << b_node

              new_nodes << parent
              i = idx_next + 1
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
