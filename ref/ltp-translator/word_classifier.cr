# Word Classifier Module
# Checks if a word belongs to certain categories using suffixes or POS tags

require "./pos_tag"

module QTran
  module WordClassifier
    extend self

    # Suffix lists (loaded once at runtime)
    class_getter place_suffixes : Set(Char) = load_suffixes("places")
    class_getter person_suffixes : Set(Char) = load_suffixes("persons")
    class_getter org_suffixes : Set(Char) = load_suffixes("orgs")
    class_getter temporal_suffixes : Set(Char) = load_suffixes("temporals")

    # Load suffix list from file
    private def load_suffixes(name : String) : Set(Char)
      suffixes = Set(Char).new

      # Try multiple paths for suffix files
      paths = [
        "etc/suffixes/#{name}.txt",
        "./etc/suffixes/#{name}.txt",
        File.join(File.dirname(__FILE__), "../../etc/suffixes/#{name}.txt"),
      ]

      paths.each do |path|
        if File.exists?(path)
          File.each_line(path) do |line|
            line = line.strip
            next if line.empty? || line.starts_with?('#')
            # Take last character as suffix
            suffixes << line[-1] if line.size > 0
          end
          break
        end
      end

      suffixes
    end

    # Check if word is a place by suffix or POS tag
    def place?(word : String, tag : PosTag) : Bool
      return true if tag.n_place?
      return true if word.size > 0 && place_suffixes.includes?(word[-1])
      false
    end

    # Check if word is a person by suffix or POS tag
    def person?(word : String, tag : PosTag) : Bool
      return true if tag.n_person?
      return true if word.size > 0 && person_suffixes.includes?(word[-1])
      false
    end

    # Check if word is an organization by suffix or POS tag
    def org?(word : String, tag : PosTag) : Bool
      return true if tag.n_org?
      return true if word.size > 0 && org_suffixes.includes?(word[-1])
      false
    end

    # Check if word is a temporal/time expression by suffix or POS tag
    # Used for 会 → sẽ (future) context detection
    def temporal?(word : String, tag : PosTag) : Bool
      return true if tag == PosTag::NTime
      return true if word.size > 0 && temporal_suffixes.includes?(word[-1])
      false
    end

    # Check if word is a "missable" object (can be target of 想 → nhớ)
    # Includes: persons, places, organizations, pronouns
    def missable?(word : String, tag : PosTag) : Bool
      return true if tag.pronoun?
      return true if person?(word, tag)
      return true if place?(word, tag)
      return true if org?(word, tag)
      false
    end
  end
end
