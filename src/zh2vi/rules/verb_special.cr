# VerbSpecial - Special verb pattern rules ported from old LTP-translator
# Handles:
# 1. A-not-A questions (V不V / V没V → có V không/chưa)
# 2. Copula 是 emphasis (S + 是 + VP → S + đúng là + VP)

require "../node"

module Zh2Vi::Rules
  module VerbSpecial
    extend self

    def process(node : Node) : Node
      # Recurse children first (post-order)
      node.children = node.children.map { |c| process(c) }

      # 1. A-not-A: Look for VNV nodes
      process_a_not_a(node)

      # 2. Copula emphasis: Look for VP containing VC + VP
      process_copula(node)

      node
    end

    # A-not-A questions: V不V / V没V → có V không/chưa
    # Tree structure: VNV → [V, AD(不/没), V]
    # Sometimes followed by a sibling VP/IP with the actual verb (e.g. 想不想去)
    private def process_a_not_a(node : Node) : Nil
      # Find VNV child
      vnv_idx = node.children.index { |c| c.label == "VNV" }
      return unless vnv_idx

      vnv = node.children[vnv_idx]
      return unless vnv.children.size >= 3

      # Extract V1, negation, V2
      v1 = vnv.children[0]
      neg = vnv.children[1]
      v2 = vnv.children[2]

      neg_text = neg.token.try(&.text)
      return unless neg_text == "不" || neg_text == "没"

      # Determine question particle: 不 → không, 没 → chưa
      question_word = neg_text == "没" ? "chưa" : "không"

      # Build: có + V1 + [following VP] + không/chưa
      # Create "có" node
      co_token = Token.new("có", "AD", nil, 0, "advmod")
      co_node = Node.leaf("AD", co_token, -1)
      co_node.vietnamese = "có"

      # Create question particle node
      q_token = Token.new(question_word, "AD", nil, 0, "advmod")
      q_node = Node.leaf("AD", q_token, -1)
      q_node.vietnamese = question_word

      # Check if there's a following sibling VP/IP (e.g. 想不想去 → the 去 part)
      following = node.children[vnv_idx + 1]?
      has_following = following && (following.label == "VP" || following.label == "IP")

      # Rebuild: replace VNV (and optionally following VP) with [có, V1, (following), question]
      new_children = node.children[0...vnv_idx].dup
      new_children << co_node
      new_children << v1

      if has_following && following
        new_children << following
        # Remove both VNV and following
        remaining = vnv_idx + 2 < node.children.size ? node.children[(vnv_idx + 2)..] : [] of Node
        new_children.concat(remaining)
      else
        remaining = vnv_idx + 1 < node.children.size ? node.children[(vnv_idx + 1)..] : [] of Node
        new_children.concat(remaining)
      end

      new_children << q_node
      node.children = new_children
    end

    # Copula 是 emphasis: S + 是 + VP → S + đúng là + VP
    # When 是(VC) is followed by VP (verb phrase), it's emphatic
    # When 是(VC) is followed by NP (noun phrase), it's standard copula
    private def process_copula(node : Node) : Nil
      # Only process VP-like nodes that contain VC
      return unless node.label == "VP" || node.label == "IP"

      node.children.each_with_index do |child, idx|
        next unless child.leaf?
        next unless child.token.try(&.pos) == "VC"
        next unless child.token.try(&.text) == "是"

        # Check what follows: VP → emphatic, NP → standard copula
        next_child = node.children[idx + 1]?
        next unless next_child

        # Emphatic: 是 + VP → đúng là
        if next_child.label == "VP" || next_child.label == "IP"
          child.vietnamese = "đúng là"
        end
        # Standard copula (是 + NP): keep dictionary value "là"
      end
    end
  end
end
