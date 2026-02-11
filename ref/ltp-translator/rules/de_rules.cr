require "../node"
require "../pos_tag"
require "./de_resolver"

module QTran
  module DeRules
    extend self

    # Apply rules for 的/地/之 particles in attributive constructions
    # Pattern: [Modifier] + de + [Head] → [Head] + de + [Modifier]
    def apply(nodes : Array(MtNode), new_nodes : Array(MtNode), i : Int32) : {Bool, Int32}
      # Match: [N1] [de] [N2]
      if (n1 = nodes[i]) && (de = nodes[i + 1]?) && (n2 = nodes[i + 2]?)
        if (de.key == "的" || de.key == "地" || de.key == "之")
          # Check N2 head
          if n2.noun? || n2.pronoun? || n2.verb?
            modifier = n1

            # Special Logic: Relative Clause with Subject?
            # "Subject + Verb" or "Subject + Suo + Verb"
            if n1.verb?
              if (subject = new_nodes.last?)
                if subject.noun? || subject.pronoun?
                  # Standard S + V
                  phrase = MtNode.new("", PosTag::Verb)
                  phrase.children << subject
                  phrase.children << n1
                  new_nodes.pop
                  modifier = phrase
                elsif subject.key == "所" || subject.tag == PosTag::Part
                  # Check for Subject before Suo: "S + Suo + V"
                  suo = subject
                  new_nodes.pop # Pop Suo
                  if (real_subj = new_nodes.last?) && (real_subj.noun? || real_subj.pronoun?)
                    phrase = MtNode.new("", PosTag::Verb)
                    phrase.children << real_subj
                    phrase.children << suo
                    phrase.children << n1
                    new_nodes.pop # Pop Subject
                    modifier = phrase
                  else
                    # Just "Suo + V" (Passive marker or nominalizer)
                    # Treat Suo+V as the modifier unit
                    phrase = MtNode.new("", PosTag::Verb)
                    phrase.children << suo
                    phrase.children << n1
                    modifier = phrase
                  end
                end
              end
            elsif n1.noun? || n1.pronoun?
              # Special Logic: "Verb + Object + De + Head"
              # Only trigger if Head (n2) is Person to avoid capturing Main Verb + Object
              is_person_head = n2.tag.n_person? || WordClassifier.person?(n2.key, n2.tag)

              if is_person_head && (verb = new_nodes.last?) && verb.verb?
                phrase = MtNode.new("", PosTag::Verb)
                phrase.children << verb
                phrase.children << n1
                new_nodes.pop # Pop Verb
                modifier = phrase
              end
            end

            # Check modifier validity
            if modifier.noun? || modifier.verb? || modifier.adj? || modifier.pronoun?
              # Inherit head tag (Verb/Noun) instead of hardcoding Noun
              parent = MtNode.new("", n2.tag)

              de_val = ""

              if de.key == "地"
                de_val = "" # Adverbial 'de'
              else
                # Use DeResolver for 'de'/'zhi'
                de_val = DeResolver.resolve(modifier, de)
              end

              # Special override: Relative clause "de", often empty
              if modifier.verb? && de.key == "的"
                de_val = ""
              end

              de.val = de_val

              # Swap: [Head] [de] [Modifier]
              parent.children << n2
              unless de_val.empty?
                parent.children << de
              end
              parent.children << modifier

              new_nodes << parent
              return {true, i + 3}
            end
          end
        end
      end

      {false, i}
    end

    # Handle dangling 的/之 at end of phrase
    # Pattern: [Pronoun/Noun] + [de] → [de] + [Pronoun/Noun]
    # "Wo de" -> "Cua toi"
    def apply_dangling(nodes : Array(MtNode), new_nodes : Array(MtNode), i : Int32, skip_zhi_yi : Bool = false) : {Bool, Int32}
      if (n1 = nodes[i]) && (de = nodes[i + 1]?)
        if (de.key == "的" || de.key == "之") && (n1.pronoun? || n1.noun?)
          # Skip if this is part of 之一的 pattern (handled separately)
          if skip_zhi_yi && de.key == "之" && (yi = nodes[i + 2]?) && yi.key == "一"
            return {false, i}
          end

          parent = MtNode.new("", PosTag::Adj) # Treated as Modifier Phrase

          # Force 'cua'
          de.val = "của"

          parent.children << de
          parent.children << n1

          new_nodes << parent
          return {true, i + 2}
        end
      end

      {false, i}
    end
  end
end
