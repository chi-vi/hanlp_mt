require "./pos_tag"

module QTran
  class MtNode
    property key : String
    property val : String = ""
    property tag : PosTag
    property idx : Int32

    # Tree structure
    property children : Array(MtNode) = [] of MtNode

    # Original metadata from analysis if needed
    property raw_tag : String?

    def initialize(@key : String, @tag : PosTag = PosTag::None, @idx : Int32 = 0, @val : String = "")
      @val = @key if @val.empty?
    end

    def leaf?
      children.empty?
    end

    # Helper to flatten tree to string (for translation output)
    def to_s(io : IO)
      if val.empty?
        children.each { |c| c.to_s(io); io << " " }
      else
        io << val
      end
    end

    def to_s
      String.build { |io| to_s(io) }
    end

    # For debug
    def inspect(io : IO)
      if leaf?
        io << "Node(#{@key}:#{@val} [#{@tag}])"
      else
        io << "Node(Children: #{children.size} => [#{children.map(&.inspect).join(", ")}])"
      end
    end

    # Utility to check tags
    delegate noun?, verb?, adj?, pronoun?, part_de?, n_person?, n_dir?, n_place?, n_time?, prepos?, conj?, adverb?, to: @tag
  end
end
