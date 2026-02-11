require "../node"
require "../pos_tag"

# Forward reference to avoid circular require issues immediately,
# but Grammar will require this file.
# We will use QTran::Grammar.new.process inside.

module QTran
  module PunctuationRules
    extend self

    PAIRS = {
      "“"  => "”",
      "（"  => "）",
      "\"" => "\"",
      "("  => ")",
      "《"  => "》",
      "‘"  => "’",
      "'"  => "'",
    }

    def apply(nodes : Array(MtNode)) : Array(MtNode)
      new_nodes = [] of MtNode
      i = 0

      while i < nodes.size
        node = nodes[i]

        # Check for Open Punct
        if node.tag == PosTag::Punct && PAIRS.has_key?(node.key)
          close_char = PAIRS[node.key]

          # Look ahead for matching close
          # Limit lookahead to avoid performance kill on long sentences
          found_idx = -1
          balance = 1

          # Simple linear scan for balance
          # Note: This is a greedy match finding the balancing close.
          ((i + 1)...[(i + 20), nodes.size].min).each do |j|
            n = nodes[j]
            if n.key == node.key && n.key != close_char
              balance += 1
            elsif n.key == close_char
              balance -= 1
            end

            if balance == 0
              found_idx = j
              break
            end
          end

          if found_idx > i
            # Found a group: [i .. found_idx]

            # Content strictly between puncts
            content_nodes = nodes[(i + 1)...found_idx]

            # Recursively process content to handle internal grammar (e.g. "my" -> "của tôi")
            # We create a new Grammar instance to process the sub-sentence
            # Ensure we don't recurse infinitely? PunctuationRules consumes the parens,
            # so next level processes smaller content. Safe.

            # Need to dynamically instance Grammar to avoid circular require at top level if possible,
            # or rely on compiler resolving.
            # QTran::Grammar is defined in grammar.cr which requires this file.
            # So QTran::Grammar might not be fully defined when this file is parsed?
            # Crystal types are distinct from file parsing order often.

            processed_content = content_nodes
            # Only process if content is not empty
            if !content_nodes.empty?
              # We use a lazy way to call Grammar to avoid strict dependency loop if verified
              # Actually, simple recursion is fine if Grammar class structure allows.
              # Assuming QTran::Grammar is available.
              processed_content = QTran::Grammar.new.process(content_nodes)
            end

            # Heuristics for Tag of the Group
            group_tag = PosTag::Noun # Default fallback

            if !processed_content.empty?
              # Determine dominant tag
              if processed_content.size == 1
                group_tag = processed_content[0].tag
              else
                # Strategy: check last node
                last = processed_content.last
                if last.key == "的" || last.key == "之" || last.tag.part_de?
                  group_tag = PosTag::Adj # Treat as generic modifier
                else
                  # Scan for verb presence vs noun
                  has_verb = processed_content.any?(&.verb?)
                  has_noun = processed_content.any?(&.noun?)

                  if has_verb
                    group_tag = PosTag::Verb
                  elsif has_noun
                    group_tag = PosTag::Noun
                  elsif processed_content.any?(&.adj?)
                    group_tag = PosTag::Adj
                  end
                end
              end
            end

            parent = MtNode.new("", group_tag)

            # Add Opening Punct
            parent.children << node

            # Add Processed Content
            processed_content.each do |c|
              parent.children << c
            end

            # Add Closing Punct
            parent.children << nodes[found_idx]

            new_nodes << parent
            i = found_idx + 1
            next
          end
        end

        new_nodes << node
        i += 1
      end

      new_nodes
    end
  end
end
