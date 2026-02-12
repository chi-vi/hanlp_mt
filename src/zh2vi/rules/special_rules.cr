require "../node"

module Zh2Vi
  module Rules
    module SpecialRules
      extend self

      def process(node : Node) : Node
        # 1. Check for "Shi...de" construction (Emphasis)
        process_shi_de(node)

        # 2. Check for "Ni hao" greeting
        process_greeting(node)

        # Recurse
        node.children.each { |c| process(c) }

        node
      end

      # Handle "是...的" construction
      # VP sometimes contains VC(是) and an NP that ends with SP(的)
      private def process_shi_de(node : Node)
        return unless node.label == "VP"

        # Find "是"
        shi_child = node.children.find { |c| c.token.try { |t| t.text == "是" && t.pos == "VC" } }
        # Or sometimes "是" is inside a VRD/etc? usually simple VC
        # If not direct child, look for VC child
        shi_child ||= node.children.find { |c| c.label == "VC" && c.token.try(&.text) == "是" }

        return unless shi_child

        # Check subsequent siblings for the "de" particle
        # Usually it's in the object (NP) following "是"
        # We need to find the "的" at the end of the sentence/phrase

        # Look at the last child of the VP
        last_child = node.children.last?
        return unless last_child

        # We are looking for "的" at the end
        if de_node = find_final_de(last_child)
          # Mark for deletion: set empty translation
          de_node.vietnamese = ""
        end
      end

      private def find_final_de(node : Node) : Node?
        if node.leaf?
          text = node.token.try(&.text)
          pos = node.token.try(&.pos)
          if text == "的" && (pos == "SP" || pos == "DEC" || pos == "DEG" || pos == "AS")
            return node
          end
        else
          # Check the last child RECURSIVELY
          if last = node.children.last?
            return find_final_de(last)
          end
        end
        nil
      end

      # Handle "你/你们 + 好" -> "Chào + bạn/các bạn"
      private def process_greeting(node : Node)
        return unless node.label == "IP"

        # Expect 2 children: NP (subject) + VP (predicate)
        # Or NP + VP + PU
        return unless node.children.size >= 2

        subj = node.children[0]
        pred = node.children[1]

        # Check Subject: "你" or "你们"
        subj_text = subj.text
        return unless ["你", "你们"].includes?(subj_text)

        # Check Predicate: "好"
        # VP -> VA -> 好 OR VP -> VV -> 好 (sometimes tagged VV)
        pred_text = pred.text
        return unless ["好", "很好"].includes?(pred_text)

        # Transform!

        # 1. Update "好" -> "chào"
        set_translation(pred, "chào")

        # 2. Update Subject -> "bạn" / "các bạn"
        new_subj_text = subj_text == "你" ? "bạn" : "các bạn"
        set_translation(subj, new_subj_text)

        # 3. Swap order: Subject + Predicate -> Predicate + Subject
        # But wait, Crystal arrays don't support simple swap if we want to preserve structure
        # actually, standard Vietnamese SVO for "Chào bạn" is Verb +
        # We perform a swap of the nodes themselves within the IP parent
        node.children[0], node.children[1] = node.children[1], node.children[0]

        # Prevent further reordering (Reorder module might treat VP+NP as NP and move PU)
        node.is_atomic = true
      end

      private def set_translation(node : Node, text : String)
        if node.leaf?
          node.vietnamese = text
        else
          # If it's a phrasal node, typically only one main word
          # Set on all leaves? Or just the head?
          # For "你", it's a single leaf.
          # For "好", single leaf.
          node.leaves.each do |leaf|
            leaf.vietnamese = text
          end
        end
      end
    end
  end
end
