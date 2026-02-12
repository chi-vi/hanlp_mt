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
    # OR Flat structure: VP → [VP/V, ADVP/AD, VP/V]
    private def process_a_not_a(node : Node) : Nil
      # 1. Check for explicit VNV node
      vnv_idx = node.children.index { |c| c.label == "VNV" }

      # 2. If no VNV, check for flat pattern in VP children
      if !vnv_idx && node.label == "VP"
        # Look for triplet: [V, Neg, V] where V1 == V2
        node.children.each_with_index do |child, i|
          next if i + 2 >= node.children.size

          v1 = child
          neg = node.children[i + 1]
          v2 = node.children[i + 2]

          # Check Negation
          neg_text = neg.token.try(&.text) || neg.leaves.first?.try(&.token).try(&.text)
          next unless neg_text == "不" || neg_text == "没"

          # Check Verbs (must be same text)
          v1_text = v1.token.try(&.text) || v1.leaves.first?.try(&.token).try(&.text)
          v2_text = v2.token.try(&.text) || v2.leaves.first?.try(&.token).try(&.text)
          next unless v1_text && v2_text && v1_text == v2_text

          # Check Labels (loose check for V/VP)
          next unless expected_verb_label?(v1) && expected_verb_label?(v2)

          # Found it! vnv_idx is effectively 'i', but we need to handle structural replacement manually here
          # Transformation: Replace [V1, Neg, V2] with [Có, V1, Question]
          transform_a_not_a(node, i, v1, neg_text.not_nil!, v2)
          return # Handle one per node for simplicity
        end
      elsif vnv_idx
        vnv = node.children[vnv_idx]
        return unless vnv.children.size >= 3

        v1 = vnv.children[0]
        neg = vnv.children[1]
        v2 = vnv.children[2]

        neg_text = neg.token.try(&.text)
        return unless neg_text == "不" || neg_text == "没"

        # Rewrite the VNV node itself
        transform_vnv_node(vnv, v1, neg_text.not_nil!, v2)

        # Now we might have a sibling VP following VNV (e.g. 想不想 [去])
        # transform_vnv_node handles internal structure, but we might want to wrap the following VP?
        # Actually logic in flat handling replaces VNV with [Có, V, Q]. following VP remains as sibling.
        # "Có Muốn Không Đi" -> correct is "Có Muốn Đi Không".
        # So Q needs to jump AFTER following VP if exists.

        handle_following_vp(node, vnv_idx, neg_text == "没" ? "chưa" : "không")
      end
    end

    private def expected_verb_label?(node : Node) : Bool
      node.label == "VP" || node.label == "VV" || node.label == "VA" || node.label == "VC" || node.label == "VE"
    end

    # Transform VNV node internally: [V1, Neg, V2] → [Có, V1, Q]
    private def transform_vnv_node(vnv : Node, v1 : Node, neg_text : String, v2 : Node) : Nil
      q_word = neg_text == "没" ? "chưa" : "không"

      co_node = create_adverb("có")
      q_node = create_adverb(q_word)

      vnv.children = [co_node, v1, q_node]
    end

    # Transform flat [V1, Neg, V2] sequence in parent
    private def transform_a_not_a(parent : Node, idx : Int32, v1 : Node, neg_text : String, v2 : Node) : Nil
      q_word = neg_text == "没" ? "chưa" : "không"

      co_node = create_adverb("có")
      q_node = create_adverb(q_word)

      # Replace [V1, Neg, V2] with [Có, V1, Q]
      # But checking for following VP to move Q to end

      new_children = parent.children.dup

      # Determine end of structure
      end_idx = idx + 2 # Index of V2

      # Check if next sibling is VP/IP that should be included (e.g. 想不想 [去])
      following = parent.children[end_idx + 1]?
      has_following = following && (following.label == "VP" || following.label == "IP")

      # Construct new sequence
      replacement = [co_node, v1]

      if has_following && following
        replacement << following
        replacement << q_node
        # Remove V1, Neg, V2, Following
        # Range: idx .. end_idx+1
        parent.children.delete_at(idx, 4) # 3 + 1
      else
        replacement << q_node
        # Remove V1, Neg, V2
        parent.children.delete_at(idx, 3)
      end

      # Insert replacement
      replacement.reverse_each do |n|
        parent.children.insert(idx, n)
      end
    end

    # Handle moving Q to after sibling VP for VNV case
    private def handle_following_vp(parent : Node, vnv_idx : Int32, q_word : String) : Nil
      vnv = parent.children[vnv_idx]

      # Check following sibling
      following = parent.children[vnv_idx + 1]?
      return unless following && (following.label == "VP" || following.label == "IP")

      # If VNV is [Có, V1, Q], we want [Có, V1, Following, Q]
      # So we need to pull Q out of VNV and put it after Following?
      # Or fuse them?
      # Easiest: Splice VNV children into Parent, and move Q

      # VNV children: [Có, V1, Q]
      return unless vnv.children.size == 3
      co = vnv.children[0]
      v1 = vnv.children[1]
      q = vnv.children[2]

      # New sequence in parent: [..., Có, V1, Following, Q, ...]
      parent.children[vnv_idx] = co
      parent.children.insert(vnv_idx + 1, v1)
      # following is at vnv_idx + 2 now
      # insert Q at vnv_idx + 3
      parent.children.insert(vnv_idx + 3, q)
    end

    private def create_adverb(text : String) : Node
      token = Token.new(text, "AD", nil, 0, "advmod")
      node = Node.leaf("AD", token, -1)
      node.vietnamese = text
      node
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
