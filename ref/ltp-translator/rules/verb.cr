require "../node"
require "../pos_tag"
require "../word_classifier"

module QTran
  module VerbRules
    extend self

    def apply(nodes : Array(MtNode)) : Array(MtNode)
      new_nodes = [] of MtNode
      i = 0

      while i < nodes.size
        # 0.0 Special Handling for "Hui" (Know vs Will)
        # Must run BEFORE Time reordering moves context away.
        if (verb = nodes[i]) && verb.key == "会" && verb.verb?
          is_future = false
          if (prev = nodes[i - 1]?)
            # Check preceding Adverb "Yiding" (Certainty)
            if prev.key == "一定"
              is_future = true
            end
            # Check preceding Time Word using suffix+POS detection
            if WordClassifier.temporal?(prev.key, prev.tag)
              is_future = true
            end
            # Check for future markers
            if prev.key == "将"
              is_future = true
            end
            # Check for "想...会" pattern: 想 + Pronoun + 会
            # Example: 我想他会来 (I suppose he will come)
            # prev is pronoun (他), prev.prev should be 想
            if prev.pronoun? && (prev_prev = nodes[i - 2]?) && prev_prev.key == "想"
              is_future = true
            end
          end
          if is_future
            verb.val = "sẽ"
          end
          # Do NOT 'next' here, allow strict reordering to proceed if needed.
        end

        # 0.0.1 Special Handling for "Xiang" (想) - Context-dependent meanings
        # Default: muốn (want) - kept from dictionary
        # Context patterns:
        # - 想到 → nghĩ đến (think of/about) - handled as compound verb in dict
        # - 想 + Pronoun/Person/Place/Org → nhớ (miss)
        # - 想 + Pronoun + Verb clause → tưởng (suppose)
        # - 想 + Verb → muốn (want) - default from dict
        if (verb = nodes[i]) && verb.key == "想" && verb.verb?
          if (next_node = nodes[i + 1]?)
            # Check if next token is a "missable" object using suffix+POS detection
            if WordClassifier.missable?(next_node.key, next_node.tag)
              # Distinguish between:
              # "我想你" (I miss you) → nhớ
              # "我想他会来" (I suppose he will come) → tưởng
              # Check if there's a following verb (indicating a clause)
              if (next_next = nodes[i + 2]?) && next_next.verb?
                verb.val = "tưởng" # Suppose (pronoun + clause)
              else
                verb.val = "nhớ" # Miss (just object)
              end
            end
            # Default: 想 + Verb → muốn (want) - dict already handles this
          end
        end

        # 0.0.2 A-not-A Questions: V + 不/没 + V → có + V + không/chưa
        # Examples: 去不去 → có đi không, 吃没吃 → có ăn chưa
        if (v1 = nodes[i]) && (v1.verb? || v1.tag == PosTag::Adj)
          if (neg = nodes[i + 1]?) && (neg.key == "不" || neg.key == "没")
            if (v2 = nodes[i + 2]?) && v2.key == v1.key
              parent = MtNode.new("", PosTag::Verb)

              # Create "có" node
              co_node = MtNode.new("có", PosTag::Adverb)
              co_node.val = "có"
              parent.children << co_node
              parent.children << v1

              # Check for following verb (e.g., 想不想去 - the 去)
              extra_consumed = 0
              if (v3 = nodes[i + 3]?) && v3.verb?
                parent.children << v3
                extra_consumed = 1
              end

              # Add không/chưa based on negation type
              khong_node = MtNode.new(neg.key == "没" ? "chưa" : "không", PosTag::Adverb)
              khong_node.val = neg.key == "没" ? "chưa" : "không"
              parent.children << khong_node

              new_nodes << parent
              i += 3 + extra_consumed
              next
            end
          end
        end

        # 0.0.3 Copula 'Shi' (是) Emphasis
        # Pattern: Pronoun + 是 + Verb -> đúng là + Verb
        if (verb = nodes[i]) && verb.key == "是" && verb.verb?
          if (prev = nodes[i - 1]?) && prev.pronoun?
            if (nxt = nodes[i + 1]?) && nxt.verb?
              verb.val = "đúng là"
            end
          end
        end

        # 0.1 SOV -> SVO Reordering (Topic Comment)
        # Match: [Probable Subject] [Probable Object] [Verb]
        # "Ta Hanyu Shuo..."
        if (subj = nodes[i]) && (obj = nodes[i + 1]?) && (verb = nodes[i + 2]?)
          if (subj.pronoun? || subj.tag == PosTag::Noun) && (obj.tag == PosTag::Noun) && verb.verb?
            # Check for implicit SOV.
            # "Ta Hanyu Shuo".
            # Swap Obj+Verb -> Verb+Obj.

            # Need to be careful not to break "Adj + Noun" or "Noun + Noun" compounds.
            # But "Hanyu Shuo" (Chinese Speak) -> "Speak Chinese".
            # Output: [Subj] [Verb] [Obj]

            # We consume Subj, Obj, Verb.
            # Create Phrase? No, just reordered stream.
            new_nodes << subj
            new_nodes << verb
            new_nodes << obj

            i += 3
            next
          end
        end

        # 0. Time + Verb Reordering
        # Also Time + Subject -> Subject + Time

        # Check Time Node
        is_time = false
        time = nodes[i]
        if time
          if time.tag == PosTag::NTime || (time.tag == PosTag::Noun && (time.key == "明天" || time.key == "昨天" || time.key == "今天" || time.key == "今年"))
            is_time = true
          end
        end

        if is_time && time # Helper check
          # Case A: Time + Verb -> Verb + Time
          if (verb = nodes[i + 1]?) && verb.verb?
            # Special: If verb is "会" (Hui), set val to "sẽ" (Future) because it's preceded by Time.
            # For Hui, we do NOT reorder: "Ngay mai se X" is more natural than "Se X ngay mai".
            if verb.key == "会"
              verb.val = "sẽ"
              new_nodes << time
              new_nodes << verb
              # Also consume the following verb (e.g., 下雨)
              if (vobj = nodes[i + 2]?) && vobj.verb?
                new_nodes << vobj
                i += 3
              else
                i += 2
              end
              next
            end

            parent = MtNode.new("", PosTag::Verb)

            # Check for Object after Verb
            # Match: [Time] [Verb] [Obj] -> [Verb] [Obj] [Time]
            # VN: "Hom qua ta di thu vien" is natural, but "Ta di thu vien hom qua" is also good.
            # Current logic swaps [Time] [Verb] -> [Verb] [Time].
            # If we have [Verb] [Time] [Obj], it becomes "Di hom qua thu vien" (Bad).
            # So if we swap, we MUST put Time *after* Object if Object exists.

            idx_obj = i + 2
            has_obj = false
            obj = nodes[idx_obj]?
            if obj && (obj.noun? || obj.pronoun?)
              has_obj = true
            end

            parent.children << verb
            if has_obj && obj
              parent.children << obj
            end
            parent.children << time

            new_nodes << parent
            i += (has_obj ? 3 : 2)
            next
          end

          # Case B: Time + Subject -> Subject + Time (Noun/Pronoun)
          # "ZuoTian Wo" -> "Wo ZuoTian"
          # Avoid swapping if Subject is also Time (Time + Time compound)
          if (subj = nodes[i + 1]?) && (subj.noun? || subj.pronoun?)
            should_swap = true
            if subj.tag == PosTag::NTime
              should_swap = false
            end

            if should_swap
              # Swap order in output
              new_nodes << subj
              new_nodes << time
              i += 2
              next
            end
          end
        end

        # 1. Ba/Bei Constructions
        if (prep = nodes[i]) && (obj = nodes[i + 1]?) && (verb = nodes[i + 2]?)
          # Ba: A Ba B V -> A V B
          if prep.key == "把" && (obj.noun? || obj.pronoun?) && verb.verb?
            parent = MtNode.new("", PosTag::Verb)

            # Check particle [Le] after verb?
            part_node : MtNode? = nil
            is_modal = false

            if (part = nodes[i + 3]?) && (part.key == "了" || part.key == "着" || part.key == "过")
              part_node = part
              if part.key == "了"
                nxt = nodes[i + 4]?
                if nxt.nil? || nxt.tag == PosTag::Punct
                  is_modal = true
                end
              end
              i += 4
            else
              i += 3
            end

            # Aspectual Prefix Logic
            if part_node && !is_modal
              # Default Aspect
              val = (part_node.key == "了" || part_node.key == "过") ? "đã" : "đang"
              part_node.val = val

              if part_node.key == "了"
                # Suppression Check
                if (prev = new_nodes.last?) && (prev.key == "已经" || prev.key == "曾经" || prev.key == "刚" || prev.key == "刚刚")
                  part_node.val = ""
                end
              end

              unless part_node.val.empty?
                parent.children << part_node
              end
            end

            parent.children << verb
            parent.children << obj

            # Modal Suffix Logic (UNGROUPED)
            if part_node && is_modal
              # Only Le is treated as Modal here for now
              if part_node.key == "了"
                part_node.val = "rồi"
                new_nodes << parent
                new_nodes << part_node
                next
              else
                # Fallback for others if they somehow end up here (Logic restricts is_modal to Le)
              end
            end

            new_nodes << parent
            next
          end

          # Bei: A Bei B V -> A Bi B V
          if prep.key == "被" && (obj.noun? || obj.pronoun?) && verb.verb?
            parent = MtNode.new("", PosTag::Verb)

            # Prefix "Da/Dang" logic check
            has_le = false
            if (part = nodes[i + 3]?) && (part.key == "了" || part.key == "着" || part.key == "过")
              part_val = (part.key == "了" || part.key == "过") ? "đã" : "đang"
              part.val = part_val
              parent.children << part
              has_le = true
            end

            prep.val = "bị"
            parent.children << prep
            parent.children << obj
            parent.children << verb

            new_nodes << parent
            i += (has_le ? 4 : 3)
            next
          end
        end

        # 1.5 Special Handling for "Hui" (Know vs Will) - Standalone Context Check
        # This handles cases like "Ta Yiding Hui" where Hui is not immediately after Time.
        if (verb = nodes[i]) && verb.key == "会" && verb.verb?
          is_future = false
          # Check preceding Adverb "Yiding" (Certainty)
          if (prev = nodes[i - 1]?) && prev.key == "一定"
            is_future = true
          end
          if is_future
            verb.val = "sẽ"
          end
        end

        # 2. Verb + Particle
        # Match: [Verb] + [Le/Zhe/Guo]
        if (verb = nodes[i]) && (part = nodes[i + 1]?)
          if verb.verb? && (part.tag == PosTag::PartLe || part.key == "了" || part.key == "着" || part.key == "过")
            parent = MtNode.new("", PosTag::Verb)
            handled = false

            case part.key
            when "了"
              # Check Context: Aspectual (Prefix) vs Modal (Suffix)
              is_modal = false
              nxt = nodes[i + 2]?
              if nxt.nil? || nxt.tag == PosTag::Punct
                is_modal = true
              end

              if is_modal
                part.val = "rồi"
                new_nodes << verb
                new_nodes << part # Suffix (Separate Node)
                i += 2
                next
              else
                # Aspectual: "đã" + Verb
                part.val = "đã"

                # Check for Suppression (Preceding Time Adverb)
                # "Yijing Chi Le" -> "Da An" (Not "Da Da An")
                if (prev = new_nodes.last?) && (prev.key == "已经" || prev.key == "曾经" || prev.key == "刚" || prev.key == "刚刚")
                  part.val = ""
                end

                unless part.val.empty?
                  parent.children << part
                end
                parent.children << verb
              end
              handled = true
            when "着"
              part.val = "đang"
              parent.children << part
              parent.children << verb
              handled = true
            when "过"
              part.val = "đã từng"
              parent.children << part
              parent.children << verb
              handled = true
            end

            if handled
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
