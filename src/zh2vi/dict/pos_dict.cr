require "json"
require "../utt"

module Zh2Vi::Dict
  # PosDict looks up word translations based on token + UTT tag
  # Format: Each line in JSONL is ["tok", "utt", "val"]
  # Where utt is one of: N, V, A, D, P, M, NR, I, F, X
  class PosDict
    # Internal storage: tok -> {utt -> val}
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

        tok, utt, val = arr[0], arr[1], arr[2]
        dict.add(tok, utt, val)
      end
      dict
    end

    # Add an entry
    def add(tok : String, utt : String, val : String) : Nil
      @data[tok] ||= Hash(String, String).new
      @data[tok][utt] = val
    end

    # Look up translation by tok + POS tag (converts to UTT internally)
    def lookup(tok : String, pos : String, ner : String? = nil) : String?
      utt = UTT.for_token(pos, ner)
      lookup_utt(tok, utt)
    end

    # Look up translation by tok + UTT tag directly
    def lookup_utt(tok : String, utt : String) : String?
      variants = @data[tok]?
      return nil unless variants

      # 1. Try exact UTT match
      if val = variants[utt]?
        return val
      end

      # 2. Try fallback UTT
      if fallback_utt = UTT.fallback(utt)
        if val = variants[fallback_utt]?
          return val
        end
      end

      # 3. Try X (default) tag
      variants["X"]?
    end

    # Look up translation by tok only (fallback, returns first match)
    def lookup_any(tok : String) : String?
      @data[tok]?.try(&.values.first?)
    end

    # Get all UTT variants for a token
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
