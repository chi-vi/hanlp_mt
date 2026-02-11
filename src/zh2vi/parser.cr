require "./node"
require "json"
require "yaml"
require "./data/raw_con"

module Zh2Vi
  # Parser converts HanLP MTL output into a Node tree
  class Parser
    # Parse constituency tree from RawCon struct
    def parse_tree(con : RawCon) : Node
      label = con.cpos

      case body = con.body
      when String
        # Leaf node
        Node.new(label: label, token: Token.new(body, label))
      when Array(RawCon)
        # Branch node
        children = body.map { |c| parse_tree(c) }
        Node.new(label: label, children: children)
      else
        raise "Invalid RawCon body type"
      end
    end

    # Parse constituency tree from bracket notation (Legacy)
    # Input: "(IP (NP (PN 我)) (VP (VV 爱) (NP (PN 你))))"
    def parse_con(bracket : String) : Node
      bracket = bracket.strip
      raise "Empty input" if bracket.empty?
      raise "Invalid bracket notation: must start with (" unless bracket.starts_with?('(')

      tokens = tokenize(bracket)
      node, _ = parse_tokens(tokens, 0)
      node
    end

    # Parse using bracket string (Backward compatibility)
    def parse(
      con : String,
      cws : Array(String),
      pos : Array(String),
      ner : Array(NerSpan) = [] of NerSpan,
      dep : Array(DepRel) = [] of DepRel,
    ) : Node
      tree = parse_con(con)
      process_tree(tree, cws, pos, ner, dep)
    end

    # Parse using RawCon
    def parse(
      con : RawCon,
      cws : Array(String),
      pos : Array(String),
      ner : Array(NerSpan) = [] of NerSpan,
      dep : Array(DepRel) = [] of DepRel,
    ) : Node
      tree = parse_tree(con)
      process_tree(tree, cws, pos, ner, dep)
    end

    private def process_tree(
      tree : Node,
      cws : Array(String),
      pos : Array(String),
      ner : Array(NerSpan),
      dep : Array(DepRel),
    ) : Node
      # Build token info from cws, pos, dep
      token_info = build_tokens(cws, pos, ner, dep)

      # Assign tokens to leaf nodes
      assign_tokens(tree, token_info, 0)

      # Integrate NER: mark entities as atomic
      integrate_ner(tree, ner)

      tree
    end

    private def tokenize(bracket : String) : Array(String)
      tokens = [] of String
      current = String::Builder.new
      in_token = false

      bracket.each_char do |c|
        case c
        when '('
          if current.bytesize > 0
            tokens << current.to_s
            current = String::Builder.new
          end
          tokens << "("
        when ')'
          if current.bytesize > 0
            tokens << current.to_s
            current = String::Builder.new
          end
          tokens << ")"
        when ' ', '\t', '\n', '\r'
          if current.bytesize > 0
            tokens << current.to_s
            current = String::Builder.new
          end
        else
          current << c
        end
      end

      if current.bytesize > 0
        tokens << current.to_s
      end

      tokens
    end

    private def parse_tokens(tokens : Array(String), pos : Int32) : {Node, Int32}
      raise "Expected '(' at position #{pos}" unless tokens[pos]? == "("
      pos += 1

      # Next token is the label
      label = tokens[pos]
      pos += 1

      children = [] of Node

      while pos < tokens.size && tokens[pos] != ")"
        if tokens[pos] == "("
          # Child node
          child, pos = parse_tokens(tokens, pos)
          children << child
        else
          # Leaf token (text)
          text = tokens[pos]
          # Create leaf node - token info will be filled later
          leaf = Node.new(label: label, token: Token.new(text, label))
          return {leaf, pos + 2} # Skip text and ')'
        end
      end

      # Skip closing ')'
      pos += 1

      node = Node.new(label: label, children: children)
      {node, pos}
    end

    private def build_tokens(
      cws : Array(String),
      pos : Array(String),
      ner : Array(NerSpan),
      dep : Array(DepRel),
    ) : Array(Token)
      tokens = [] of Token

      cws.each_with_index do |text, i|
        pos_tag = pos[i]? || "X"

        # Find NER label for this token
        ner_label = nil
        ner.each do |span|
          if span.covers?(i)
            ner_label = span.label
            break
          end
        end

        # Find DEP info for this token (1-indexed in dep)
        dep_head = 0
        dep_rel = "root"
        dep.each do |rel|
          if rel.dependent == i + 1 # DEP is 1-indexed
            dep_head = rel.head
            dep_rel = rel.relation
            break
          end
        end

        tokens << Token.new(text, pos_tag, ner_label, dep_head, dep_rel)
      end

      tokens
    end

    private def assign_tokens(node : Node, tokens : Array(Token), idx : Int32) : Int32
      if node.leaf?
        if idx < tokens.size
          node.token = tokens[idx]
          node.index = idx
          # Update label from POS if it's a pre-terminal
          if node.token
            # Keep constituency label, but store POS in token
          end
        end
        return idx + 1
      end

      node.children.each do |child|
        idx = assign_tokens(child, tokens, idx)
      end
      idx
    end

    private def integrate_ner(node : Node, ner_spans : Array(NerSpan)) : Nil
      return if ner_spans.empty?

      # Get leaf indices covered by this node
      leaves = node.leaves
      return if leaves.empty?

      first_idx = leaves.first.index
      last_idx = leaves.last.index
      return unless first_idx && last_idx

      # Check if this node exactly matches an NER span
      ner_spans.each do |span|
        if first_idx == span.start_idx && last_idx == span.end_idx - 1
          # This node matches the NER span exactly
          node.is_atomic = true
          node.label = "#{node.label}-#{span.label}"
          return
        end
      end

      # Recurse to children
      node.children.each do |child|
        integrate_ner(child, ner_spans)
      end
    end
  end
end
