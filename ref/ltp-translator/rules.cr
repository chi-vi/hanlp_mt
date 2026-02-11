require "./node"
require "./pos_tag"
require "./rules/*"

module QTran
  module Rules
    extend self

    def apply_all(head : MtNode) : MtNode
      curr : MtNode? = head

      # Iteration max count to prevent infinite loops globally?
      count = 0

      # Traverse the list
      while curr
        # Apply strict ordering of rules?
        # Or just apply all to current node?

        # Some rules might move `curr` (remove/insert).
        # Implementations return the 'next' node to process or 'curr' if no change.

        next_node = apply_strategies(curr)

        if next_node != curr
          # Structure changed or focus shifted
          curr = next_node
        else
          curr = curr.succ
        end

        count += 1
        break if count > 1000 # Safety break for short sentences
      end

      # Find new head
      new_head = head
      while new_head.prev
        new_head = new_head.prev.not_nil!
      end
      new_head
    end

    def apply_strategies(node : MtNode) : MtNode
      # Try each rule set.
      # If a rule changes the structure, it returns the new node to focus on.
      # If not, it returns the same node.

      # Order matters!

      # 1. Comparison (A bi B adj -> A adj hon B) - affects Noun/Adj order
      res = CompareRules.apply(node)
      return res if res != node

      # 2. Prepositions (Zai + Loc + V -> V + Zai + Loc)
      res = PreposRules.apply(node)
      return res if res != node

      # 3. Verbs (Ba, Bei, Particles)
      res = VerbRules.apply(node)
      return res if res != node

      # 4. Nouns (Adj+N, N+de+N) - usually local swaps
      res = NounRules.apply(node)
      return res if res != node

      node
    end
  end
end
