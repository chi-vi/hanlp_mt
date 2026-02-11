require "./node"
require "./parser"
require "./drt"
require "./dict/*"
require "./rules/*"
require "./data/raw_con"

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

    # Full translation pipeline (String input)
    def translate(
      con : String,
      cws : Array(String),
      pos : Array(String),
      ner : Array(NerSpan) = [] of NerSpan,
      dep : Array(DepRel) = [] of DepRel,
    ) : Node
      # 1. Parse into tree structure
      tree = @parser.parse(con, cws, pos, ner, dep)
      run_pipeline(tree, cws, dep)
    end

    # Full translation pipeline (RawCon input)
    def translate(
      con : RawCon,
      cws : Array(String),
      pos : Array(String),
      ner : Array(NerSpan) = [] of NerSpan,
      dep : Array(DepRel) = [] of DepRel,
    ) : Node
      # 1. Parse into tree structure
      tree = @parser.parse(con, cws, pos, ner, dep)
      run_pipeline(tree, cws, dep)
    end

    private def run_pipeline(tree : Node, cws : Array(String), dep : Array(DepRel)) : Node
      # 1.5. Apply structural dependency rules (Ba, Bei, Localizers)
      tree = Rules::DeprelRules.process(tree)

      # 2. Apply reordering rules
      tree = Rules::Reorder.process(tree, @pos_dict)

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
    # See: doc/deprel-tagset.md for full documentation
    #
    # DEP dictionary format: ["child", "parent", "DRT", "child_val", "parent_val"]
    # Priority is determined by DRT.BIAS - lower bias = higher priority
    private def lookup_by_dep(text : String, idx : Int32, cws : Array(String), dep : Array(DepRel)) : String?
      dep_idx = idx + 1 # DEP is 1-indexed

      # Find all relations involving this word
      as_head = dep.select { |r| r.head == dep_idx }
      as_dependent = dep.select { |r| r.dependent == dep_idx }

      # Collect all potential matches with their DRT bias
      candidates = [] of {Int32, String} # {bias, translation}

      # === Process relations where this word is HEAD ===

      # Check CLF - Lượng từ (special: tra ngược theo danh từ)
      as_head.each do |rel|
        next unless rel.relation == "clf"
        clf_idx = rel.dependent - 1
        next unless clf_idx >= 0 && clf_idx < cws.size
        clf = cws[clf_idx]

        if match = @dep_dict.lookup(text, clf, "CLF")
          candidates << {DRT.bias("CLF"), match.child_val}
        end
      end

      # Check OBJ relations (dobj, ba)
      as_head.each do |rel|
        drt = DRT.from_deprel(rel.relation)
        next unless drt == "OBJ"

        obj_idx = rel.dependent - 1
        next unless obj_idx >= 0 && obj_idx < cws.size
        obj = cws[obj_idx]

        # Try original deprel first for backward compatibility
        if match = @dep_dict.lookup(text, obj, rel.relation)
          candidates << {DRT.bias("OBJ"), match.child_val}
        elsif match = @dep_dict.lookup(text, obj, "OBJ")
          # Then try DRT tag
          candidates << {DRT.bias("OBJ"), match.child_val}
        end
      end

      # Check AGT relations (nsubj, top, xsubj, csubj)
      as_head.each do |rel|
        drt = DRT.from_deprel(rel.relation)
        next unless drt == "AGT"

        subj_idx = rel.dependent - 1
        next unless subj_idx >= 0 && subj_idx < cws.size
        subj = cws[subj_idx]

        # Try original deprel first
        if match = @dep_dict.lookup(text, subj, rel.relation)
          candidates << {DRT.bias("AGT"), match.child_val}
        elsif match = @dep_dict.lookup(text, subj, "AGT")
          candidates << {DRT.bias("AGT"), match.child_val}
        end
      end

      # === Process relations where this word is DEPENDENT ===

      # Check RES - Bổ ngữ kết quả (highest priority)
      as_dependent.each do |rel|
        drt = DRT.from_deprel(rel.relation)
        next unless drt == "RES"

        head_idx = rel.head - 1
        next unless head_idx >= 0 && head_idx < cws.size
        head = cws[head_idx]

        # Try original deprel first
        if match = @dep_dict.lookup(text, head, rel.relation)
          candidates << {DRT.bias("RES"), match.child_val}
        elsif match = @dep_dict.lookup(text, head, "RES")
          candidates << {DRT.bias("RES"), match.child_val}
        end
      end

      # Check other dependent relations
      as_dependent.each do |rel|
        head_idx = rel.head - 1
        next unless head_idx >= 0 && head_idx < cws.size
        head = cws[head_idx]

        drt = DRT.from_deprel(rel.relation)
        next if drt == "RES" || drt == "OTH" # Already handled or fallback

        # Try original deprel first for backward compatibility
        if match = @dep_dict.lookup(text, head, rel.relation)
          if val = match.child_val
            candidates << {DRT.bias(drt), val}
          end
        elsif match = @dep_dict.lookup(text, head, drt)
          # Then try DRT tag
          if val = match.child_val
            candidates << {DRT.bias(drt), val}
          end
        end
      end

      # Return highest priority match (lowest bias)
      return nil if candidates.empty?
      candidates.sort_by! { |c| c[0] }
      candidates.first[1]
    end

    # Get Vietnamese output as string
    def output_text(tree : Node) : String
      # Collect and filter empty strings
      text = collect_vietnamese(tree).reject(&.empty?).join(" ").strip
      clean_output(text)
    end

    # Clean up output text (deduplication, etc.)
    private def clean_output(text : String) : String
      # Remove duplicate time markers
      text = text.gsub(/(đã)\s+\1/, "\\1")
      text = text.gsub(/(sẽ)\s+\1/, "\\1")
      text = text.gsub(/(đang)\s+\1/, "\\1")
      text
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
