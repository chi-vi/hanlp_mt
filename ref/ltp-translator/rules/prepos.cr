require "../node"
require "../pos_tag"

module QTran
  module PreposRules
    extend self

    def apply(nodes : Array(MtNode)) : Array(MtNode)
      new_nodes = [] of MtNode
      i = 0

      while i < nodes.size
        # 1. Generic Preposition Reordering: [Prep] [Obj] [Verb] -> [Verb] [Prep] [Obj]
        # Applies to: Zai (At), Gei (To/For), Gen (With), Wang (Towards)

        if (prep = nodes[i]) && prep.tag.prepos?
          key = prep.key
          # Target prepositions
          if key == "在" || key == "给" || key == "跟" || key == "和" || key == "往" || key == "从"
            # Check for Object of Prep (Loc/Noun/Pronoun)
            idx_obj = i + 1
            if (p_obj = nodes[idx_obj]?) && (p_obj.noun? || p_obj.pronoun? || p_obj.n_place? || p_obj.n_dir? || p_obj.tag == PosTag::Number)
              # Check for Verb following PP
              idx_verb = idx_obj + 1
              if (verb = nodes[idx_verb]?) && verb.verb?
                # Check for Object of Verb (Subject to move?)
                # Usually: [Prep Obj] [Verb] [VObj] -> [Verb] [VObj] [Prep Obj]
                idx_vobj = idx_verb + 1
                v_obj = nodes[idx_vobj]?
                has_v_obj = v_obj && (v_obj.noun? || v_obj.pronoun?)

                parent = MtNode.new("", PosTag::Verb)

                # Create PP Node
                pp_node = MtNode.new("", PosTag::Prepos)

                # Value Mapping
                case key
                when "在"      then prep.val = "ở"
                when "给"      then prep.val = "cho"
                when "跟", "和" then prep.val = "với"
                when "往"      then prep.val = "về"
                when "从"      then prep.val = "từ"
                end

                pp_node.children << prep
                pp_node.children << p_obj

                # Reorder: Verb [+ VObj] + PP
                parent.children << verb
                if has_v_obj && v_obj
                  parent.children << v_obj
                end
                parent.children << pp_node

                new_nodes << parent
                i = has_v_obj ? idx_vobj + 1 : idx_verb + 1
                next
              end
            end
          end
        end

        # 2. Comparison: A + Bi + B + Adj -> A + Adj + Hon + B
        if (bi = nodes[i]) && (b_node = nodes[i + 1]?) && (adj = nodes[i + 2]?)
          if bi.tag.prepos? && bi.key == "比" && adj.adj?
            parent = MtNode.new("", PosTag::Adj) # Becomes Adj Phrase
            bi.val = "hơn"

            # Output: Adj + Hon + B
            parent.children << adj
            parent.children << bi
            parent.children << b_node

            new_nodes << parent
            i += 3
            next
          end
        end

        # Default
        new_nodes << nodes[i]
        i += 1
      end

      new_nodes
    end
  end
end
