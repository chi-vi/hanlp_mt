require "../node"
require "../pos_tag"
require "./de_resolver"
require "./zhi_rules"
require "./de_rules"

module QTran
  module NounRules
    extend self

    def apply(nodes : Array(MtNode)) : Array(MtNode)
      new_nodes = [] of MtNode
      i = 0

      while i < nodes.size
        # 0. Conjunction Grouping (Greedy)
        if (n1 = nodes[i]) && (conj = nodes[i + 1]?) && (n2 = nodes[i + 2]?)
          # Remove comma "," from grouping to prevent clause bleeding
          is_list_sep = conj.tag.conj? || (conj.tag == PosTag::Punct && conj.key == "、")

          if is_list_sep
            # Check types
            if (n1.adj? && n2.adj?) || (n1.verb? && n2.verb?) || (n1.noun? && n2.noun?)
              parent = MtNode.new("", n1.tag) # Inherit type
              parent.children << n1
              parent.children << conj
              parent.children << n2

              new_nodes << parent
              i += 3
              next
            end
          end
        end

        # 0.5 Special Pattern: X + 之 + 一 + 的 + Head (handled by ZhiRules)
        matched, new_i = ZhiRules.apply(nodes, new_nodes, i)
        if matched
          i = new_i
          next
        end

        # 1. Attributive/Adverbial/RelClause: [Phrase] + de + [Head] (handled by DeRules)
        matched, new_i = DeRules.apply(nodes, new_nodes, i)
        if matched
          i = new_i
          next
        end

        # 2. Adj + Noun
        if (adj = nodes[i]) && (noun = nodes[i + 1]?)
          if adj.adj? && noun.noun?
            # Exception: "Zhengge" (Whole) - Do NOT swap
            if adj.key == "整个"
              # Keep as Adj + Noun
              parent = MtNode.new("", PosTag::Noun)
              parent.children << adj
              parent.children << noun
              new_nodes << parent
              i += 2
              next
            end

            parent = MtNode.new("", PosTag::Noun)
            parent.children << noun
            parent.children << adj

            new_nodes << parent
            i += 2
            next
          end
        end

        # 3. Noun + Localizer
        if (noun = nodes[i]) && (loc = nodes[i + 1]?)
          if noun.noun? && loc.n_dir?
            parent = MtNode.new("", PosTag::NDir)
            parent.children << loc
            parent.children << noun

            new_nodes << parent
            i += 2
            next
          end
        end

        # 4. Noun + Noun
        if (n1 = nodes[i]) && (n2 = nodes[i + 1]?)
          # Allow Time+Time swap
          should_swap = false
          if (n1.noun? || n1.pronoun?) && (n2.noun? || n2.pronoun?)
            # Exclude Zheme/Name from noun compounding (they are treated as adverbs/comparisons later)
            if n2.key == "这么" || n2.key == "那么"
              new_nodes << nodes[i]
              i += 1
              next
            end

            # Prevent swapping "NTime NTime" if logic requires

            # Special override for Time
            if n1.tag == PosTag::NTime && n2.tag == PosTag::NTime
              should_swap = true
            end

            # General Noun/Pronoun Modifiers handling
            # Always swap Mod + Head -> Head + Mod
            if n1.noun? && n2.noun? && !should_swap
              should_swap = true
            end

            # Special Logic for Pronoun + Noun
            if n1.pronoun? && (n2.noun? || n2.tag.n_person? || n2.tag.n_place? || n2.tag.n_org? || n2.pronoun?)
              # Check if n2 is possessable/relationship
              if WordClassifier.person?(n2.key, n2.tag) ||
                 WordClassifier.place?(n2.key, n2.tag) ||
                 WordClassifier.org?(n2.key, n2.tag) ||
                 n2.key == "自己" # Force swap for Ziji
                should_swap = true
              end
            end
          end

          if should_swap
            parent = MtNode.new("", PosTag::Noun)
            parent.children << n2
            parent.children << n1

            new_nodes << parent
            i += 2
            next
          end
        end

        # 5. Possessive End-Phrase Adjustment (Dangling De) - handled by DeRules
        matched, new_i = DeRules.apply_dangling(nodes, new_nodes, i, skip_zhi_yi: true)
        if matched
          i = new_i
          next
        end

        new_nodes << nodes[i]
        i += 1
      end

      new_nodes
    end
  end
end
