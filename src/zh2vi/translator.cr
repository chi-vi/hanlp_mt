require "./node"
require "./parser"
require "./dict/*"
require "./rules/*"

module Zh2Vi
  # Translator is the main engine for Chinese to Vietnamese translation
  # It combines parsing, reordering, and dictionary lookup
  class Translator
    getter pos_dict : Dict::PosDict
    getter dep_dict : Dict::DepDict
    getter hanviet : Dict::HanViet
    getter parser : Parser

    def initialize(
      @pos_dict : Dict::PosDict,
      @dep_dict : Dict::DepDict,
      @hanviet : Dict::HanViet,
    )
      @parser = Parser.new
    end

    # Create translator with default/minimal dictionaries
    def self.default : Translator
      Translator.new(
        Dict::PosDict.new,
        Dict::DepDict.new,
        Dict::HanViet.default
      )
    end

    # Load translator from data files
    def self.load(
      pos_dict_path : String,
      dep_dict_path : String,
      hanviet_path : String? = nil,
    ) : Translator
      pos_dict = Dict::PosDict.load(pos_dict_path)
      dep_dict = Dict::DepDict.load(dep_dict_path)
      hanviet = hanviet_path ? Dict::HanViet.load(hanviet_path) : Dict::HanViet.default

      Translator.new(pos_dict, dep_dict, hanviet)
    end

    # Full translation pipeline
    def translate(
      con : String,
      cws : Array(String),
      pos : Array(String),
      ner : Array(NerSpan) = [] of NerSpan,
      dep : Array(DepRel) = [] of DepRel,
    ) : Node
      # 1. Parse into tree structure
      tree = @parser.parse(con, cws, pos, ner, dep)

      # 2. Apply reordering rules
      tree = Rules::Reorder.process(tree)

      # 3. Translate leaf nodes using dictionaries
      translate_tree(tree, cws, dep)

      tree
    end

    # Translate just from a parsed tree
    def translate_tree(tree : Node, cws : Array(String) = [] of String, dep : Array(DepRel) = [] of DepRel) : Nil
      tree.traverse_postorder do |node|
        if node.leaf? && node.vietnamese.nil?
          node.vietnamese = lookup_word(node, cws, dep)
        end
      end
    end

    # Look up translation for a token
    def lookup_word(node : Node, cws : Array(String), dep : Array(DepRel)) : String
      token = node.token
      return "?" unless token

      text = token.text
      pos = token.pos

      # 1. Try DEP-based lookup first (highest priority for disambiguation)
      if (idx = node.index) && !dep.empty?
        dep_match = lookup_by_dep(text, idx, cws, dep)
        return dep_match if dep_match
      end

      # 2. Try POS-based lookup (with NER for UTT conversion)
      if result = @pos_dict.lookup(text, pos, token.ner)
        return result
      end

      # 3. Try any POS lookup as fallback
      if result = @pos_dict.lookup_any(text)
        return result
      end

      # 4. For NER entities, use Hán-Việt
      if token.ner
        return @hanviet.convert_proper(text)
      end

      # 5. Final fallback: Hán-Việt conversion
      @hanviet.convert(text)
    end

    # Look up using dependency relations
    # DEP dictionary format: ["child_word", "parent_word", "deprel", "child_val", "parent_val"]
    # For verb-object: verb is head, object is dependent with "dobj" relation
    # The dictionary stores: ["verb", "object", "dobj", "verb_translation", "object_translation"]
    private def lookup_by_dep(text : String, idx : Int32, cws : Array(String), dep : Array(DepRel)) : String?
      # Find dependency relation for this word
      dep_idx = idx + 1 # DEP is 1-indexed

      # Case 1: This word is the HEAD (e.g., verb with dobj dependent)
      # Look up by finding what this word governs
      dep.each do |rel|
        if rel.head == dep_idx
          # This word is the head, rel.dependent is the dependent
          dep_word_idx = rel.dependent - 1
          if dep_word_idx >= 0 && dep_word_idx < cws.size
            dep_word = cws[dep_word_idx]
            # Look up: text is the verb (child in dict), dep_word is the object (parent in dict)
            if match = @dep_dict.lookup(text, dep_word, rel.relation)
              return match.child_val
            end
          end
        end
      end

      # Case 2: This word is a DEPENDENT
      # Look up by finding what governs this word
      dep.each do |rel|
        if rel.dependent == dep_idx
          head_word_idx = rel.head - 1
          if head_word_idx >= 0 && head_word_idx < cws.size
            head_word = cws[head_word_idx]
            # Look up: head_word is the verb, text is the object
            if match = @dep_dict.lookup(head_word, text, rel.relation)
              # Return parent_val (translation of this word as object)
              return match.parent_val if match.parent_val
            end
          end
        end
      end

      nil
    end

    # Get Vietnamese output as string
    def output_text(tree : Node) : String
      collect_vietnamese(tree).join
    end

    # Collect Vietnamese translations in order
    private def collect_vietnamese(node : Node) : Array(String)
      if node.leaf?
        [node.vietnamese || node.token.try(&.text) || ""]
      else
        node.children.flat_map { |c| collect_vietnamese(c) }
      end
    end
  end
end
