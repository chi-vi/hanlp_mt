# Compare - Comparison/equative construction rules
# Ported from old LTP-translator's compare.cr
#
# Handles:
# 1. 比 comparative: A 比 B Adj → A Adj hơn B
#    Tree: VP → [PP(P(比)+NP(B)), (ADVP), VP(Adj)]
#
# 2. 没有 negative comparison: A 没有 B (这么) Adj → A không Adj bằng B
#    Tree: VP → [VE(没有), IP(NP(B)+VP(Adj))]
#
# 3. Equative: A 跟/像 B 一样 Adj → A Adj như B
#    Tree: VP → [PP(P(跟/像)+NP(B)), ADVP(一样), VP(Adj)]
#
# 4. Simile: 如 B Adj → Adj như B
#    Tree: VP → [VV(如), IP(NP(B)+VP(Adj))]

require "../node"

module Zh2Vi::Rules
  module Compare
    extend self

    # Comparative prepositions
    BI_WORDS = {"比", "比较"}

    # Negative comparison
    MEIYOU_WORDS = {"没有", "没"}

    # Equative prepositions
    EQUATIVE_PREPS = {"跟", "和", "像"}

    # Simile verbs
    SIMILE_VERBS = {"如", "像"}

    # Yiyang markers consumed in equative
    YIYANG_WORDS = {"一样", "一般"}

    def process(node : Node) : Node
      # Recurse children first (post-order)
      node.children = node.children.map { |c| process(c) }

      process_bi(node)
      process_meiyou(node)
      process_equative(node)
      process_nested_equative(node)
      process_simile(node)

      node
    end

    # Nested Equative: Parent -> [Mod, Head]
    # Mod contains [PP(跟/像+B), Word(一样)]
    # Head is VP(Adj)
    # Transform to: [Head, như, B]
    private def process_nested_equative(node : Node) : Nil
      return unless node.children.size >= 2
      # Potential Mod + Head pattern
      # Scan distinct pairs
      (0...(node.children.size - 1)).each do |i|
        mod = node.children[i]
        head = node.children[i + 1]

        # Check Head (should be VP/VA)
        next unless head.label == "VP" || head.label == "VA" || (head.leaf? && head.token.try(&.pos) == "VA")

        # Unwrap Mod if it is IP/VP with single child (wrapper)
        if mod.children.size == 1 && (mod.label == "IP" || mod.label == "VP")
          mod = mod.children.first
        end

        # Check Mod (should contain PP(Equative) and Word(一样))

        pp_node = nil
        yiyang_node = nil

        # Look for PP in Mod immediate children
        pp_idx = mod.children.index do |c|
          c.label == "PP" && c.leaves.first?.try(&.token).try(&.text).try { |t| EQUATIVE_PREPS.includes?(t) }
        end

        if pp_idx
          pp_node = mod.children[pp_idx]
          # Look for Yiyang in siblings of PP
          yiyang_idx = mod.children.index do |c|
            next false unless c.label == "ADVP" || c.label == "VP" || c.leaf?
            leaf = c.leaf? ? c : c.leaves.first?
            text = leaf.try(&.token).try(&.text)
            text && YIYANG_WORDS.includes?(text)
          end

          if yiyang_idx
            yiyang_node = mod.children[yiyang_idx]
          end
        end

        # If strict sibling struct not found, maybe recursive search in Mod?
        # But for now, let's stick to the structure seen in test: IP -> VP(PP, VP(一样))
        # So Mod is that VP. Children are PP and VP(一样).

        next unless pp_node && yiyang_node

        # Extraction logic
        prep_node = pp_node.children.find { |c| c.leaf? && EQUATIVE_PREPS.includes?(c.token.try(&.text) || "") }
        b_nodes = pp_node.children.reject { |c| c == prep_node }
        next if b_nodes.empty?

        # Construct new nodes
        nhu_token = Token.new("như", "AD", nil, 0, "advmod")
        nhu_node = Node.leaf("AD", nhu_token, -1)
        nhu_node.vietnamese = "như"

        # Structural change:
        # Parent children: ... + Mod + Head + ...
        # Replace [Mod, Head] with [Head, như, B...]

        insert_nodes = [head, nhu_node] + b_nodes

        # Remove Mod and Head (index i and i+1)
        node.children.delete_at(i, 2)

        # Insert new sequence
        insert_nodes.reverse_each { |n| node.children.insert(i, n) }

        # Adjust index or break (handling one per node for safety)
        # Since we modified structure significantly, safer to return/break or handle carefully.
        # But we iterate on index range which is fixed range.
        # After insert, size changed.
        return
      end
    end

    # 比 comparative: VP → [PP(比+B), (ADVP), VP(Adj)] → [(ADVP), VP(Adj), hơn, B]
    private def process_bi(node : Node) : Nil
      return unless node.label == "VP" || node.label == "IP"

      # Find PP starting with 比
      pp_idx = node.children.index do |c|
        c.label == "PP" && c.leaves.first?.try(&.token).try(&.text).try { |t| BI_WORDS.includes?(t) }
      end
      return unless pp_idx

      pp_node = node.children[pp_idx]

      # Extract B (the comparison target) from PP
      # PP → [P(比), NP(B)]
      bi_node = pp_node.children.find { |c| c.leaf? && BI_WORDS.includes?(c.token.try(&.text) || "") }
      b_nodes = pp_node.children.reject { |c| c == bi_node }
      return if b_nodes.empty? || !bi_node

      # Set 比 → hơn
      bi_node.vietnamese = "hơn"

      # Find the adj/VP (last child usually)
      # Collect everything after PP (ADVP, VP, etc.)
      after_pp = node.children[(pp_idx + 1)..]
      before_pp = node.children[0...pp_idx]

      # Reorder: before_pp + after_pp + hơn + B
      node.children = before_pp + after_pp + [bi_node] + b_nodes
    end

    # 没有 negative comparison: VP → [VE(没有), IP(NP(B)+VP(Adj))] → [không, Adj, bằng, B]
    private def process_meiyou(node : Node) : Nil
      return unless node.label == "VP" || node.label == "IP"

      # Find 没有 (VE or VV)
      meiyou_idx = node.children.index do |c|
        c.leaf? && MEIYOU_WORDS.includes?(c.token.try(&.text) || "") &&
          (c.token.try(&.pos) == "VE" || c.token.try(&.pos) == "AD")
      end
      return unless meiyou_idx

      meiyou = node.children[meiyou_idx]

      # Find following IP that contains NP(B) + VP(Adj)
      ip_idx = meiyou_idx + 1
      ip = node.children[ip_idx]?
      return unless ip && (ip.label == "IP" || ip.label == "VP")

      # Extract B (NP) and Adj (VP) from IP
      b_node = ip.children.find { |c| c.label == "NP" || c.label == "PN" || (c.leaf? && (c.token.try(&.pos) == "PN" || c.token.try(&.pos) == "NR")) }
      adj_node = ip.children.find { |c| c.label == "VP" || (c.leaf? && c.token.try(&.pos) == "VA") }
      return unless b_node && adj_node

      # Set 没有 → không
      meiyou.vietnamese = "không"

      # Create bằng node
      bang_token = Token.new("bằng", "AD", nil, 0, "advmod")
      bang_node = Node.leaf("AD", bang_token, -1)
      bang_node.vietnamese = "bằng"

      # Reorder: before + không + Adj + bằng + B + rest
      before = node.children[0...meiyou_idx]
      after = ip_idx + 1 < node.children.size ? node.children[(ip_idx + 1)..] : [] of Node

      node.children = before + [meiyou, adj_node, bang_node, b_node] + after
    end

    # Equative: VP → [PP(跟/像+B), ADVP(一样), VP(Adj)] → [Adj, như, B]
    private def process_equative(node : Node) : Nil
      return unless node.label == "VP" || node.label == "IP"

      # Find PP with equative prep
      pp_idx = node.children.index do |c|
        c.label == "PP" && c.leaves.first?.try(&.token).try(&.text).try { |t| EQUATIVE_PREPS.includes?(t) }
      end
      return unless pp_idx

      pp_node = node.children[pp_idx]

      # Find 一样 ADVP
      yiyang_idx = node.children.index do |c|
        next false unless c.label == "ADVP" || c.leaf?
        leaf = c.leaf? ? c : c.leaves.first?
        text = leaf.try(&.token).try(&.text)
        text && YIYANG_WORDS.includes?(text)
      end
      return unless yiyang_idx

      # Find the adj VP
      adj_idx = node.children.index { |c|
        idx = node.children.index(c) || 0
        idx > pp_idx && (c.label == "VP" || (c.leaf? && c.token.try(&.pos) == "VA"))
      }
      return unless adj_idx

      adj_node = node.children[adj_idx]

      # Extract B from PP (skip the preposition)
      prep_node = pp_node.children.find { |c| c.leaf? && EQUATIVE_PREPS.includes?(c.token.try(&.text) || "") }
      b_nodes = pp_node.children.reject { |c| c == prep_node }
      return if b_nodes.empty?

      # Create như node
      nhu_token = Token.new("như", "AD", nil, 0, "advmod")
      nhu_node = Node.leaf("AD", nhu_token, -1)
      nhu_node.vietnamese = "như"

      # Reorder: [stuff before PP] + Adj + như + B + [stuff after adj]
      before = node.children[0...pp_idx]
      after_indices = (0...node.children.size).reject { |i| i == pp_idx || i == yiyang_idx || i == adj_idx }
      after_nodes = after_indices.select { |i| i > adj_idx }.map { |i| node.children[i] }

      node.children = before + [adj_node, nhu_node] + b_nodes + after_nodes
    end

    # Simile: VP → [VV(如), IP(NP(B)+VP(Adj))] → [Adj, như, B]
    private def process_simile(node : Node) : Nil
      return unless node.label == "VP" || node.label == "IP"

      # Find 如 verb
      ru_idx = node.children.index do |c|
        c.leaf? && SIMILE_VERBS.includes?(c.token.try(&.text) || "") &&
          c.token.try(&.pos) == "VV"
      end
      return unless ru_idx

      ru_node = node.children[ru_idx]

      # Find following IP/VP with NP(B) + VP(Adj)
      ip_idx = ru_idx + 1
      ip = node.children[ip_idx]?
      return unless ip && (ip.label == "IP" || ip.label == "VP")

      # Extract B and Adj
      b_node = ip.children.find { |c| c.label == "NP" || (c.leaf? && c.token.try(&.pos) == "NN") }
      adj_node = ip.children.find { |c| c.label == "VP" || (c.leaf? && c.token.try(&.pos) == "VA") }
      return unless b_node && adj_node

      # Set 如 → như
      ru_node.vietnamese = "như"

      # Reorder: [before] + Adj + như + B + [after]
      before = node.children[0...ru_idx]
      after = ip_idx + 1 < node.children.size ? node.children[(ip_idx + 1)..] : [] of Node

      node.children = before + [adj_node, ru_node, b_node] + after
    end
  end
end
