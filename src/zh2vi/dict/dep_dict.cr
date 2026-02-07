require "json"

module Zh2Vi::Dict
  # Result of a DEP dictionary lookup
  struct DepMatch
    getter child_val : String
    getter parent_val : String?

    def initialize(@child_val : String, @parent_val : String? = nil)
    end
  end

  # DepDict looks up word translations based on dependency relations
  # Format: Each line in JSONL is ["child", "parent", "deprel", "child_val", "parent_val"]
  #
  # Pattern matching:
  # - parent can be "*suffix" or "prefix*" for wildcard matching
  # - deprel can be "*" to match all relations
  # - When wildcard is used, parent_val is not applied
  class DepDict
    # Entry in the dictionary
    private struct Entry
      getter child : String
      getter parent : String
      getter deprel : String
      getter child_val : String
      getter parent_val : String?
      getter? parent_is_pattern : Bool
      getter? deprel_is_wildcard : Bool

      def initialize(
        @child : String,
        @parent : String,
        @deprel : String,
        @child_val : String,
        @parent_val : String?,
      )
        @parent_is_pattern = @parent.includes?("*")
        @deprel_is_wildcard = @deprel == "*"
      end

      # Check if this entry matches the given parent string
      def matches_parent?(parent_text : String) : Bool
        if @parent_is_pattern
          if @parent.starts_with?("*")
            # *suffix pattern
            suffix = @parent[1..]
            parent_text.ends_with?(suffix)
          elsif @parent.ends_with?("*")
            # prefix* pattern
            prefix = @parent[0...-1]
            parent_text.starts_with?(prefix)
          else
            false
          end
        else
          @parent == parent_text
        end
      end

      # Check if this entry matches the given deprel
      def matches_deprel?(rel : String) : Bool
        @deprel_is_wildcard || @deprel == rel
      end

      # Full match check
      def matches?(child_text : String, parent_text : String, rel : String) : Bool
        @child == child_text && matches_parent?(parent_text) && matches_deprel?(rel)
      end

      def to_match : DepMatch
        # If parent used wildcard, don't return parent_val
        pval = @parent_is_pattern ? nil : @parent_val
        DepMatch.new(@child_val, pval)
      end
    end

    @entries : Array(Entry)
    # Index by child for faster lookup
    @by_child : Hash(String, Array(Entry))

    def initialize
      @entries = [] of Entry
      @by_child = Hash(String, Array(Entry)).new
    end

    # Load dictionary from JSONL file
    def self.load(path : String) : DepDict
      dict = DepDict.new
      File.each_line(path) do |line|
        line = line.strip
        next if line.empty?

        arr = Array(JSON::Any).from_json(line)
        next unless arr.size >= 5

        child = arr[0].as_s
        parent = arr[1].as_s
        deprel = arr[2].as_s
        child_val = arr[3].as_s
        parent_val = arr[4].as_s? # Can be null

        dict.add(child, parent, deprel, child_val, parent_val)
      end
      dict
    end

    # Add an entry
    def add(child : String, parent : String, deprel : String, child_val : String, parent_val : String?) : Nil
      entry = Entry.new(child, parent, deprel, child_val, parent_val)
      @entries << entry
      @by_child[child] ||= [] of Entry
      @by_child[child] << entry
    end

    # Look up translation based on child, parent, and dependency relation
    # Returns the most specific match (exact > pattern > wildcard)
    def lookup(child : String, parent : String, deprel : String) : DepMatch?
      candidates = @by_child[child]?
      return nil unless candidates

      # Find matches, sorted by specificity
      # Priority: exact parent + exact rel > exact parent + * rel > pattern parent + exact rel > pattern parent + * rel
      exact_exact : Entry? = nil
      exact_wild : Entry? = nil
      pattern_exact : Entry? = nil
      pattern_wild : Entry? = nil

      candidates.each do |entry|
        next unless entry.matches?(child, parent, deprel)

        if !entry.parent_is_pattern? && !entry.deprel_is_wildcard?
          exact_exact = entry
        elsif !entry.parent_is_pattern? && entry.deprel_is_wildcard?
          exact_wild = entry
        elsif entry.parent_is_pattern? && !entry.deprel_is_wildcard?
          pattern_exact = entry
        else
          pattern_wild = entry
        end
      end

      # Return most specific match
      (exact_exact || exact_wild || pattern_exact || pattern_wild).try(&.to_match)
    end

    def size : Int32
      @entries.size
    end
  end
end
