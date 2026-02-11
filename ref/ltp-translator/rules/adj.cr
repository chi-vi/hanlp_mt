require "../node"
require "../pos_tag"

module QTran
  module AdjRules
    extend self

    def apply(nodes : Array(MtNode)) : Array(MtNode)
      new_nodes = [] of MtNode
      i = 0

      while i < nodes.size
        # 1. Measure + Adj -> Adj + Measure
        # Pattern: [Num] [Quant] [Adj] OR [MeasurePhrase] [Adj]
        # Example: "Wu Chi Gao" (5 Foot Tall) -> "Gao Wu Chi" (Tall 5 Foot)

        # Check for Num + Quant (Measure group)
        if (num = nodes[i]) && num.tag == PosTag::Number
          if (quant = nodes[i + 1]?) && quant.tag == PosTag::Quant
            if (adj = nodes[i + 2]?) && adj.adj?
              # Check if Adj is followed by Noun?
              # If "Wu Chi Gao Ren" (5 Foot Tall Person) -> "Ren Gao Wu Chi" (Person Tall 5 Foot)
              # Wait, "Na San Ben Da Shu" (That 3 Vol Big Book).
              # [San Ben] [Da] [Shu].
              # If we swap [San Ben] [Da] -> [Da] [San Ben].
              # Then we get "Da San Ben Shu".
              # NounRules does Noun+Noun? Or Adj+Noun (Da, San Ben).
              # This breaks the "Num Cls" modifying "Noun" relationship.

              # Heuristic: If Adj is followed by Noun, assume [Measure] modifies [Adj+Noun] or [Measure] modifies [Noun].
              # In "Num Cls Adj Noun", generally "Num Cls" modifies "Noun" (or "Adj Noun").
              # In "Num Cls Adj" (end of sentence), "Num Cls" modifies "Adj" (Measurement).

              if (check_noun = nodes[i + 3]?) && (check_noun.noun? || check_noun.pronoun?)
                # Don't swap if Noun follows
                new_nodes << nodes[i]
                i += 1
                next
              end

              parent = MtNode.new("", PosTag::Adj)

              # Create Measure Node
              measure = MtNode.new("", PosTag::Noun) # Treat as Noun Phrase
              measure.children << num
              measure.children << quant

              # Output: Adj + Measure
              parent.children << adj
              parent.children << measure

              new_nodes << parent
              i += 3
              next
            end
          end
        end

        # Handle already grouped Measure? (Not common yet unless NounRules did it)

        # 2. Adj + Dao + Le + Extent -> Adj + Dao + Extent + Le(Roi)
        # Fix logic for [Dao] [Le] in complement structures.
        if (adj = nodes[i]) && adj.adj?
          if (dao = nodes[i + 1]?) && (dao.key == "到")
            # [Adj] [Dao] ...
            if (le = nodes[i + 2]?) && (le.key == "了")
              # Check for Extent
              if (ext = nodes[i + 3]?)
                parent = MtNode.new("", PosTag::Adj)

                # Le in this complement structure usually acts as completion (roi) at end,
                # OR just emphatic.
                # "Hao dao le ji dian" -> "Tot den cuc diem roi" or "Tot den cuc diem".

                le.val = "rồi" # Override "đã" from VerbRules if it hasn't run yet?
                # Actually VerbRules runs BEFORE Noun/Adj usually.
                # Wait, if VerbRules runs first, "Dao" (Verb/Prep) + "Le" might have been captured!
                # "Dao" is 'v' in LTP often. So VerbRules might serve [Dao Le] -> [Da Dao].
                # We need to ensure logic handles this.
                # Let's inspect if [Dao] is currently available or grouped.

                parent.children << adj
                parent.children << dao
                parent.children << ext
                parent.children << le

                new_nodes << parent
                i += 4
                next
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
