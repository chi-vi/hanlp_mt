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
    # Map to their Vietnamese translation
    POST_ADVERBS = {
      "最"  => "nhất",
      "最为" => "nhất",
      "这么" => "như thế này",
      "那么" => "như thế đó",
      "如此" => "như thế đó",
      "非常" => "vô cùng",
      "十分" => "mười phần",
      "好好" => "cho tốt",
      "极了" => "hết sức", # or cực kỳ/lắm
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
        if advp.label == "ADVP" && (head.label == "VP" || head.label == "ADJP" || head.label == "VA")
          # Get the adverb text
          adv_leaf = advp.leaves.first?
          adv_text = adv_leaf.try(&.token).try(&.text)

          if adv_text && POST_ADVERBS.has_key?(adv_text)
            # Set translation
            if adv_leaf
              adv_leaf.vietnamese = POST_ADVERBS[adv_text]
            end

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

        # Also handle already-post-posed structure?
        # If we see Head + ADVP, we might still want to translate the ADVP if it matches known ones.
        # But 'process' runs recursively, so simple translation should happen via dictionary if not handled here.
        # Let's ensure we translate even if order is already correct (e.g. 极了)

        # Check current child at i (might be ADVP that was skipped or post-posed)
        check_translation(node.children[i])

        i += 1
      end

      # Check last child
      if node.children.size > 0
        check_translation(node.children.last)
      end
    end

    private def check_translation(node : Node) : Nil
      if node.label == "ADVP" || (node.leaf? && node.token.try(&.pos) == "AD")
        leaf = node.leaf? ? node : node.leaves.first?
        text = leaf.try(&.token).try(&.text)
        if text && POST_ADVERBS.has_key?(text)
          leaf.not_nil!.vietnamese = POST_ADVERBS[text]
        end
      end
    end
  end
end
