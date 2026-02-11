module Zh2Vi
  # Token represents a leaf node with linguistic information from HanLP
  struct Token
    # Original Chinese text
    getter text : String

    # CTB POS tag (NN, VV, LC, DEC, DEG, BA, etc.)
    getter pos : String

    # OntoNotes NER label (PERSON, ORG, GPE, DATE, etc.)
    getter ner : String?

    # Index of the head word in dependency tree (0 = root)
    getter dep_head : Int32

    # Dependency relation label (nsubj, dobj, etc.)
    getter dep_rel : String

    def initialize(
      @text : String,
      @pos : String,
      @ner : String? = nil,
      @dep_head : Int32 = 0,
      @dep_rel : String = "root",
    )
    end

    def to_s(io : IO) : Nil
      io << @text
      io << "/" << @pos
      io << "/" << @ner if @ner
    end
  end

  # NER span representing an entity in the sentence
  struct NerSpan
    getter start_idx : Int32
    getter end_idx : Int32
    getter label : String

    def initialize(@start_idx : Int32, @end_idx : Int32, @label : String)
    end

    def covers?(idx : Int32) : Bool
      idx >= @start_idx && idx < @end_idx
    end

    def size : Int32
      @end_idx - @start_idx
    end
  end

  # Dependency relation from HanLP DEP output
  struct DepRel
    getter head : Int32      # Index of head word (1-indexed, 0 = root)
    getter dependent : Int32 # Index of dependent word (1-indexed)
    getter relation : String # Relation type (nsubj, dobj, etc.)

    def initialize(@head : Int32, @dependent : Int32, @relation : String)
    end
  end

  # Node represents a node in the syntax tree
  # Can be either a phrasal node (NP, VP, etc.) or a leaf node with token
  class Node
    # Constituency label (NP, VP, IP, etc.) or NER label for atomic entities
    property label : String

    # Child nodes (empty for leaf nodes)
    property children : Array(Node)

    # Token information (only for leaf nodes)
    property token : Token?

    # Vietnamese translation result
    property vietnamese : String?

    # Index in the original sentence (for leaf nodes)
    property index : Int32?

    # Whether this node is atomic (NER entity - cannot be restructured)
    property? is_atomic : Bool

    def initialize(
      @label : String,
      @children : Array(Node) = [] of Node,
      @token : Token? = nil,
      @vietnamese : String? = nil,
      @index : Int32? = nil,
      @is_atomic : Bool = false,
    )
    end

    # Create a leaf node with token
    def self.leaf(label : String, token : Token, index : Int32) : Node
      Node.new(label: label, token: token, index: index)
    end

    # Create a phrasal node with children
    def self.phrase(label : String, children : Array(Node)) : Node
      Node.new(label: label, children: children)
    end

    # Create an atomic NER node
    def self.entity(label : String, children : Array(Node)) : Node
      Node.new(label: label, children: children, is_atomic: true)
    end

    # Check if this is a leaf node
    def leaf? : Bool
      @children.empty? && !@token.nil?
    end

    # Check if this is a phrasal node
    def phrase? : Bool
      !@children.empty?
    end

    # Get all leaf nodes (tokens) in left-to-right order
    def leaves : Array(Node)
      if leaf?
        [self]
      else
        @children.flat_map(&.leaves)
      end
    end

    # Get all tokens text joined
    def text : String
      leaves.map { |n| n.token.try(&.text) || "" }.join
    end

    # Get the head child based on CTB head-finding rules
    def head_child : Node?
      return nil if leaf? || @children.empty?

      case @label
      when "VP"
        # Left-to-right: VE, VC, VV, VA, VNV, VPT, VRD, VSB, VCD, VP
        priority = %w[VE VC VV VA VNV VPT VRD VSB VCD VP]
        find_head_by_priority(@children, priority, left_to_right: true)
      when "NP"
        # Right-to-left: NP, NN, IP, NR, NT
        priority = %w[NP NN IP NR NT PN]
        find_head_by_priority(@children, priority, left_to_right: false)
      when "PP"
        # Left-to-right: P, PP
        priority = %w[P PP]
        find_head_by_priority(@children, priority, left_to_right: true)
      when "CP"
        # Right-to-left: DEC, CP, IP, VP
        priority = %w[DEC CP IP VP]
        find_head_by_priority(@children, priority, left_to_right: false)
      when "DNP"
        # Right-to-left: DEG, DNP, DEC, QP
        priority = %w[DEG DNP DEC QP]
        find_head_by_priority(@children, priority, left_to_right: false)
      when "LCP"
        # Right-to-left: LCP, LC
        priority = %w[LCP LC]
        find_head_by_priority(@children, priority, left_to_right: false)
      when "IP", "S"
        # Right-to-left: VP, IP
        priority = %w[VP IP]
        find_head_by_priority(@children, priority, left_to_right: false)
      when "QP"
        # Right-to-left: QP, CLP, CD
        priority = %w[QP CLP CD]
        find_head_by_priority(@children, priority, left_to_right: false)
      else
        # Default: rightmost child
        @children.last?
      end
    end

    # Get dependency relation of this node
    def deprel : String
      if leaf?
        @token.try(&.dep_rel) || "root"
      else
        head_child.try(&.deprel) || "root"
      end
    end

    # Deep copy the node
    def dup : Node
      Node.new(
        label: @label,
        children: @children.map(&.dup),
        token: @token,
        vietnamese: @vietnamese,
        index: @index,
        is_atomic: @is_atomic
      )
    end

    # Traverse all nodes in post-order (children first, then parent)
    def traverse_postorder(&block : Node -> Nil) : Nil
      @children.each(&.traverse_postorder(&block))
      block.call(self)
    end

    # Traverse all nodes in pre-order (parent first, then children)
    def traverse_preorder(&block : Node -> Nil) : Nil
      block.call(self)
      @children.each(&.traverse_preorder(&block))
    end

    # Find first node matching the block
    def find_node(&block : Node -> Bool) : Node?
      return self if block.call(self)

      @children.each do |child|
        if found = child.find_node(&block)
          return found
        end
      end
      nil
    end

    # Remove a descendant node (recursive)
    def remove_descendant(target : Node) : Bool
      if @children.delete(target)
        return true
      end
      @children.each do |child|
        return true if child.remove_descendant(target)
      end
      false
    end

    # Pretty print the tree
    def to_s(io : IO) : Nil
      to_s_indent(io, 0)
    end

    # Bracket notation output (like Penn Treebank)
    def to_bracket(io : IO) : Nil
      if leaf?
        io << "(" << @label << " "
        if v = @vietnamese
          io << v
        else
          io << @token.try(&.text)
        end
        io << ")"
      else
        io << "(" << @label
        @children.each do |child|
          io << " "
          child.to_bracket(io)
        end
        io << ")"
      end
    end

    def to_bracket : String
      String.build { |io| to_bracket(io) }
    end

    private def to_s_indent(io : IO, indent : Int32) : Nil
      io << "  " * indent
      io << "(" << @label
      if leaf?
        io << " "
        if v = @vietnamese
          io << v << " <- "
        end
        io << @token
        io << ")"
      else
        @children.each do |child|
          io << "\n"
          child.to_s_indent(io, indent + 1)
        end
        io << ")"
      end
    end

    private def find_head_by_priority(
      children : Array(Node),
      priority : Array(String),
      left_to_right : Bool,
    ) : Node?
      search_order = left_to_right ? children : children.reverse

      priority.each do |target|
        if found = search_order.find { |c| c.label == target || c.token.try(&.pos) == target }
          return found
        end
      end

      # Fallback to first/last child
      left_to_right ? children.first? : children.last?
    end
  end
end
