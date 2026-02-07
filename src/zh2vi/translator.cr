require "./node"
require "./parser"
require "./drt"
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

    # Look up using dependency relations with DRT-based priority
    # See: doc/relation-tagset.md for full documentation
    #
    # DEP dictionary format: ["head_word", "dep_word", "deprel|drt", "head_val", "dep_val"]
    # Priority:
    #   1. SEP (ly hợp) - merge tokens
    #   2. CLF (lượng từ) - lookup by noun
    #   3. RES/DIR (bổ ngữ) - verb + complement
    #   4. OBJ (tân ngữ) - verb + object for WSD
    private def lookup_by_dep(text : String, idx : Int32, cws : Array(String), dep : Array(DepRel)) : String?
      dep_idx = idx + 1 # DEP is 1-indexed

      # Find all relations involving this word
      as_head = dep.select { |r| r.head == dep_idx }
      as_dependent = dep.select { |r| r.dependent == dep_idx }

      # HIGH PRIORITY: Check for special DRT patterns first

      # 1. SEP - Động từ ly hợp (this word is verb, check if object forms liheci)
      as_head.each do |rel|
        next unless rel.relation == "dobj"
        obj_idx = rel.dependent - 1
        next unless obj_idx >= 0 && obj_idx < cws.size
        obj = cws[obj_idx]

        if DRT.liheci?(text, obj)
          # Look up with SEP context
          if match = @dep_dict.lookup(text, obj, "SEP")
            return match.child_val
          end
        end
      end

      # 2. CLF - Lượng từ (tra ngược theo danh từ)
      as_head.each do |rel|
        next unless rel.relation == "clf"
        clf_idx = rel.dependent - 1
        next unless clf_idx >= 0 && clf_idx < cws.size
        clf = cws[clf_idx]

        if match = @dep_dict.lookup(text, clf, "CLF")
          return match.child_val
        end
      end

      # 3. RES/DIR - Bổ ngữ (this word is complement, check head verb)
      as_dependent.each do |rel|
        next unless rel.relation == "rcomp" || rel.relation == "compound:dir"
        head_idx = rel.head - 1
        next unless head_idx >= 0 && head_idx < cws.size
        head = cws[head_idx]

        drt = DRT.direction?(text) ? "DIR" : "RES"
        if match = @dep_dict.lookup(head, text, drt)
          return match.parent_val if match.parent_val
        end
        # Also try the original deprel
        if match = @dep_dict.lookup(head, text, rel.relation)
          return match.parent_val if match.parent_val
        end
      end

      # 4. OBJ - Tân ngữ (this is head verb, lookup by object)
      as_head.each do |rel|
        next unless rel.relation == "dobj"
        obj_idx = rel.dependent - 1
        next unless obj_idx >= 0 && obj_idx < cws.size
        obj = cws[obj_idx]

        # Try original deprel first (backward compatible with existing dict)
        if match = @dep_dict.lookup(text, obj, rel.relation)
          return match.child_val
        end
        # Then try DRT tag
        if match = @dep_dict.lookup(text, obj, "OBJ")
          return match.child_val
        end
      end

      # 5. When this word is an object, return its translation
      as_dependent.each do |rel|
        next unless rel.relation == "dobj"
        head_idx = rel.head - 1
        next unless head_idx >= 0 && head_idx < cws.size
        head = cws[head_idx]

        if match = @dep_dict.lookup(head, text, "OBJ")
          return match.parent_val if match.parent_val
        end
        if match = @dep_dict.lookup(head, text, rel.relation)
          return match.parent_val if match.parent_val
        end
      end

      # 6. Generic lookup for other relations
      as_dependent.each do |rel|
        head_idx = rel.head - 1
        next unless head_idx >= 0 && head_idx < cws.size
        head = cws[head_idx]

        # Try to convert to DRT first
        if drt = DRT.from_deprel(rel.relation)
          if match = @dep_dict.lookup(head, text, drt)
            return match.parent_val if match.parent_val
          end
        end

        # Fallback to original relation
        if match = @dep_dict.lookup(head, text, rel.relation)
          return match.parent_val if match.parent_val
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
