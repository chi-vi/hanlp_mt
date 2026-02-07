require "json"

module Zh2Vi::Dict
  # PosDict looks up word translations based on token + POS tag
  # Format: Each line in JSONL is ["tok", "pos", "val"]
  class PosDict
    # Internal storage: tok -> {pos -> val}
    @data : Hash(String, Hash(String, String))

    def initialize
      @data = Hash(String, Hash(String, String)).new
    end

    # Load dictionary from JSONL file
    def self.load(path : String) : PosDict
      dict = PosDict.new
      File.each_line(path) do |line|
        line = line.strip
        next if line.empty?

        arr = Array(String).from_json(line)
        next unless arr.size >= 3

        tok, pos, val = arr[0], arr[1], arr[2]
        dict.add(tok, pos, val)
      end
      dict
    end

    # Add an entry
    def add(tok : String, pos : String, val : String) : Nil
      @data[tok] ||= Hash(String, String).new
      @data[tok][pos] = val
    end

    # Look up translation - requires both tok AND pos to match
    def lookup(tok : String, pos : String) : String?
      @data[tok]?.try(&.[pos]?)
    end

    # Look up translation by tok only (fallback, returns first match)
    def lookup_any(tok : String) : String?
      @data[tok]?.try(&.values.first?)
    end

    # Get all POS variants for a token
    def variants(tok : String) : Hash(String, String)?
      @data[tok]?
    end

    def size : Int32
      @data.values.sum(&.size)
    end

    def has_key?(tok : String) : Bool
      @data.has_key?(tok)
    end
  end
end
