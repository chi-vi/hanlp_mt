# Adverb - Degree/superlative adverb reordering rules
# Ported from old LTP-translator's adverb.cr
#
# Chinese places degree adverbs BEFORE the head: 最好, 非常好, 这么好
# Vietnamese places some AFTER the head: tốt nhất, tốt vô cùng, tốt như thế này
# But 很 keeps order: 很好 → rất tốt
#
# Tree structure: VP/ADJP → [ADVP(AD), VP/ADJP(Head)]

require "../node"

module Zh2Vi::Rules
  module Adverb
    extend self

    # Adverbs that should be post-posed (head + adverb)
    POST_ADVERBS = {
      "最", "最为",
      "这么", "那么", "如此",
      "非常", "十分", "好好",
      "极了",
    }

    # Adverbs that keep their position (adverb + head)
    # (很, etc. - handled by default, no special rule needed)

    def process(node : Node) : Node
      # Recurse children first (post-order)
      node.children = node.children.map { |c| process(c) }

      # Look for ADVP + VP/ADJP pattern within this node
      reorder_degree_adverbs(node)

      node
    end

    private def reorder_degree_adverbs(node : Node) : Nil
      return if node.children.size < 2

      # Scan for ADVP + head patterns
      i = 0
      while i < node.children.size - 1
        advp = node.children[i]
        head = node.children[i + 1]

        # Match: ADVP + VP/ADJP (head)
        if advp.label == "ADVP" && (head.label == "VP" || head.label == "ADJP")
          # Get the adverb text
          adv_leaf = advp.leaves.first?
          adv_text = adv_leaf.try(&.token).try(&.text)

          if adv_text && POST_ADVERBS.includes?(adv_text)
            # Swap: move ADVP after head
            node.children.delete_at(i)
            # Insert after the head (which is now at index i)
            insert_pos = i + 1
            insert_pos = node.children.size if insert_pos > node.children.size
            node.children.insert(insert_pos, advp)
            # Don't increment i, re-check this position
            next
          end
        end

        # Also handle VP + ADVP where ADVP is already after (e.g. 极了)
        # These are already in correct position, skip

        i += 1
      end
    end
  end
end
