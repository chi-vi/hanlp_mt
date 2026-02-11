require "../node"
require "../pos_tag"

module QTran
  module ComplementRules
    extend self

    def apply(nodes : Array(MtNode)) : Array(MtNode)
      new_nodes = [] of MtNode
      i = 0

      while i < nodes.size
        # 1. Degree / Potential Complement: [Verb/Adj] [De/Bu] [Complement]
        # Match Phase: Check various patterns starting at i.

        matched = false
        if (head = nodes[i]) && (head.verb? || head.adj?)
          # Case A: Immediate De/Bu: [Verb/Adj] [De] [Compl]
          if (part = nodes[i + 1]?) && (part.key == "得" || part.key == "地" || part.key == "的" || part.key == "不")
            if (compl = nodes[i + 2]?) && (compl.adj? || compl.verb? || compl.adverb? || compl.tag == PosTag::VCo)
              # Special Filter: Ignore "Adj + 地/的 + Verb" (Pre-verbal Manner)
              # ComplementRules usually handles Post-verbal. "地" implies Pre-verbal.
              # Only allow "Verb + 地 + Adj" (Robustness) or "Adj + 得 + Verb" (Result).
              if (part.key == "地" || part.key == "的") && head.adj? && (compl.verb? || compl.tag == PosTag::VCo)
                # Do nothing, let NounRules handle it.
              else
                parent = MtNode.new("", head.tag)

                if part.key == "得" || part.key == "地" || part.key == "的"
                  part_val = ""
                  # 1. Verb + De + Adj/Adv -> "Chay Nhanh"
                  if head.verb? && (compl.adj? || compl.adverb?)
                    part_val = ""
                    # 2. Adj + De + Verb -> "Vui den muc nhay"
                  elsif head.adj? && (compl.verb? || compl.tag == PosTag::VCo)
                    part_val = "đến mức"
                    # 3. Adj + De + Adj -> "Nong den chet"
                  elsif head.adj? && compl.adj?
                    part_val = "đến mức"
                  end

                  # Explicit check for State
                  if head.adj? && (compl.verb? || compl.tag == PosTag::VCo)
                    part_val = "đến mức"
                  end

                  part.val = part_val
                end

                # Case B: Potential (De/Bu + Verb/Result)
                if compl.verb? || compl.tag == PosTag::VCo
                  if part.key == "得" || part.key == "地" || part.key == "的"
                    # part.val = "" # handled above or default
                  elsif part.key == "不"
                    part.val = "không"
                  end
                end

                parent.children << head
                unless part.val.empty?
                  parent.children << part
                end
                parent.children << compl

                new_nodes << parent
                i += 3
                matched = true
              end
            end
          end

          # Case C: Verb + Object + De + Compl (Topic Reordered)
          # Only if Case A didn't match
          if !matched && head.verb? && (obj = nodes[i + 1]?) && (obj.noun? || obj.pronoun?)
            if (part = nodes[i + 2]?) && (part.key == "得" || part.key == "地" || part.key == "的")
              if (compl = nodes[i + 3]?) && (compl.adj? || compl.adverb?)
                # Match: Verb + Obj + De + Compl
                # Output: Verb, Obj, Compl (Drop De)

                part.val = ""

                new_nodes << head
                new_nodes << obj
                # Skip part
                new_nodes << compl

                i += 4
                matched = true
              end
            end
          end
        end

        if matched
          next
        end

        # 2. Directional Complement Fusion: [Verb] [Dir1] [Dir2]
        if (verb = nodes[i]) && verb.verb?
          # Case D: Verb + Dir1 + Dir2 (Immediate)
          if (dir1 = nodes[i + 1]?) && (dir1.key == "进" || dir1.key == "出" || dir1.key == "上" || dir1.key == "下" || dir1.key == "回")
            if (dir2 = nodes[i + 2]?) && (dir2.key == "来" || dir2.key == "去")
              # Fusion
              parent = MtNode.new("", PosTag::Verb)
              parent.children << verb
              parent.children << dir1
              new_nodes << parent
              i += 3
              next
            end
          end

          # Case E: Verb + Dir1 + Object + Dir2 (Split)
          if (dir1 = nodes[i + 1]?) && (dir1.key == "进" || dir1.key == "出" || dir1.key == "上" || dir1.key == "下" || dir1.key == "回")
            if (obj = nodes[i + 2]?) && (obj.noun? || obj.pronoun? || obj.tag == PosTag::Number)
              if (dir2 = nodes[i + 3]?) && (dir2.key == "来" || dir2.key == "去")
                # Fused Dir1+Dir2 -> Dir1. Place after Verb.
                parent = MtNode.new("", PosTag::Verb)
                parent.children << verb
                parent.children << dir1

                new_nodes << parent
                new_nodes << obj
                i += 4
                next
              end
            end
          end

          # Case F: Verb + Object + Dir1 + Dir2 (Post-posed)
          if (obj = nodes[i + 1]?) && (obj.noun? || obj.pronoun?)
            if (dir1 = nodes[i + 2]?) && (dir1.key == "进" || dir1.key == "出" || dir1.key == "上" || dir1.key == "下" || dir1.key == "回")
              if (dir2 = nodes[i + 3]?) && (dir2.key == "来" || dir2.key == "去")
                # Output: [Verb] [Obj] [Dir1]
                new_nodes << verb
                new_nodes << obj
                new_nodes << dir1
                i += 4
                next
              end
            end
          end

          # Case G: Repeated Verb
          if (obj = nodes[i + 1]?) && (obj.noun?)
            if (verb2 = nodes[i + 2]?) && verb2.verb? && verb2.val == verb.val
              if (de = nodes[i + 3]?) && (de.key == "得" || de.key == "地" || de.key == "的")
                if (compl = nodes[i + 4]?)
                  # Drop Verb2, De. Output: Verb1 Obj Compl
                  new_nodes << verb
                  new_nodes << obj
                  new_nodes << compl
                  i += 5
                  next
                end
              end
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
