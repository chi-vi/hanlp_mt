require "../node"

module Zh2Vi
  module Rules
    module PartRules
      extend self

      def process(node : Node) : Node
        # Traverse children first
        node.children.each { |c| process(c) }

        # Check for particles at this level (looking at children)
        handle_particles(node)

        node
      end

      private def handle_particles(node : Node)
        # We iterate through children to find particles and use their siblings for context
        node.children.each_with_index do |child, i|
          next unless child.leaf? && child.token

          text = child.token.not_nil!.text
          pos = child.token.not_nil!.pos

          # Check text match for particles
          case text
          when "了"
            handle_le(child, node, i)
          when "吗"
            handle_ma(child, node, i)
          when "呢"
            handle_ne(child, node, i)
          when "吧"
            handle_ba(child, node, i)
          when "啊"
            handle_a(child, node, i)
          when "嘛"
            handle_ma_tone(child, node, i)
          when "呗"
            handle_bei(child, node, i)
          when "罢了"
            child.vietnamese = "thôi"
          when "而已"
            child.vietnamese = "mà thôi"
          when "的"
            # Sentence final 'de' (SP/y/DEC/DEG)
            if pos == "SP" || pos == "y" || (i == node.children.size - 1 && node.label == "IP")
              if pos == "DEC" || pos == "DEG"
                # Default keeping existing meaning unless specific pattern
              else
                child.vietnamese = "đấy"
              end
            end
          when "啦"
            handle_la(child, node, i)
          when "耶"
            child.vietnamese = "nha"
          end
        end
      end

      # 了
      private def handle_le(leaf : Node, parent : Node, index : Int32)
        # 1. 太...了 -> quá
        tokens = parent.leaves
        leaf_idx = tokens.index(leaf)

        has_tai = false
        if leaf_idx
          # Scan backwards limited range
          start_idx = [0, leaf_idx - 5].max
          (start_idx...leaf_idx).each do |j|
            n = tokens[j]
            t = n.token.try(&.text)
            if t == "太" || t == "可"
              has_tai = true
              n.vietnamese = "" # Clear redundant "太" (quá) if handled by "le"
              break
            end
          end
        end

        if has_tai
          leaf.vietnamese = "quá"
          return
        end

        # 2. End of sentence or SP tag -> rồi
        if leaf.token.try(&.pos) == "SP" || leaf.token.try(&.pos) == "y" || index == parent.children.size - 1
          leaf.vietnamese = "rồi"
          return
        end

        # Default fallback
        if leaf.vietnamese.nil?
          leaf.vietnamese = "rồi"
        end
      end

      # 吗
      private def handle_ma(leaf : Node, parent : Node, index : Int32)
        # 1. ...了吗 -> chưa?
        tokens = parent.leaves
        leaf_idx = tokens.index(leaf)

        has_le = false
        has_shi = false

        if leaf_idx
          tokens[0...leaf_idx].each do |n|
            t = n.token.try(&.text)
            if t == "了" || t == "没"
              has_le = true
              # If "le" is "rồi", clear it because "chưa" implies "rồi".
              # Only clear if it's "了". "没" is negative marker, usually kept or handled separately?
              # "Mei...ma" -> "Chua...chua?" -> "Chua...khong?"
              # "Ban an chua?" (You eat not-yet?).
              # If "Chifan le ma", "le" -> "roi". "ma" -> "chưa" -> "an com roi chua".
              # Clear "le".
              if t == "了"
                n.vietnamese = ""
              end
            end
            has_shi = true if t == "是"
          end
        end

        if has_le
          leaf.vietnamese = "chưa"
        elsif has_shi
          leaf.vietnamese = "à" # Confirmation
        else
          # Standard question
          leaf.vietnamese = "không"
        end

        # Check previous word for topic "Zhege ma"
        prev_sibling = parent.children[index - 1]?
        if prev_sibling
          prev_text = prev_sibling.text # recursive text
          if prev_text == "这个" || prev_text == "那个"
            leaf.vietnamese = "thì"
          end
        end
      end

      # 呢
      private def handle_ne(leaf : Node, parent : Node, index : Int32)
        tokens = parent.leaves
        leaf_idx = tokens.index(leaf)

        return unless leaf_idx
        prev_tokens = tokens[0...leaf_idx]

        has_zhe = prev_tokens.any? { |n| n.token.try(&.text) == "着" }
        has_zai = prev_tokens.any? { |n| ["在", "正在"].includes?(n.token.try(&.text)) }
        has_cai = prev_tokens.any? { |n| n.token.try(&.text) == "才" }

        # Question words usually indicate "thế/vậy"
        q_words = ["谁", "什么", "哪", "哪里", "哪儿", "怎么", "几", "多"]
        has_q = prev_tokens.any? { |n| q_words.includes?(n.token.try(&.text)) }

        has_huan_mei = prev_tokens.map(&.token.try(&.text)).join.includes?("还没")

        if has_q
          if has_huan_mei || prev_tokens.any? { |n| n.token.try(&.text).try(&.starts_with?("怎么")) }
            leaf.vietnamese = "vậy"
          else
            leaf.vietnamese = "thế"
          end
        elsif has_cai
          leaf.vietnamese = "đâu"
        elsif has_zhe || has_zai
          leaf.vietnamese = "đấy" # Progressive context
        else
          # "Ni ne" -> Elliptical question
          full_text = prev_tokens.map(&.token.try(&.text)).join
          if full_text.size <= 3 && prev_tokens.any? { |n| n.token.try(&.pos) == "PN" }
            leaf.vietnamese = "thế"
          else
            leaf.vietnamese = "đấy"
          end
        end
      end

      # 吧
      private def handle_ba(leaf : Node, parent : Node, index : Int32)
        tokens = parent.leaves
        leaf_idx = tokens.index(leaf)
        return unless leaf_idx

        prev_tokens = tokens[0...leaf_idx]
        full_text = prev_tokens.map(&.token.try(&.text)).join

        if full_text.includes?("是") || full_text.includes?("会") # Speculation
          if full_text.includes?("这样")
            leaf.vietnamese = "nhỉ"
          else
            leaf.vietnamese = "chắc"
          end
        elsif ["好", "行", "可以"].includes?(full_text)
          leaf.vietnamese = "thôi" # Reluctant agreement "Hao ba"
        elsif prev_tokens.any? { |n| ["我们", "咱们"].includes?(n.token.try(&.text)) }
          leaf.vietnamese = "nhé" # Suggestion
        else
          leaf.vietnamese = "đi" # Imperative / Urging
        end
      end

      # 啊
      private def handle_a(leaf : Node, parent : Node, index : Int32)
        if index == 0
          leaf.vietnamese = "a" # Start of sentence
          return
        end

        tokens = parent.leaves
        has_q_word = tokens.any? { |n| ["什么", "哪", "谁"].includes?(n.token.try(&.text)) }
        has_exclaim = tokens.any? { |n| ["多", "真", "太", "好", "这么", "那么"].includes?(n.token.try(&.text)) }
        has_neg = tokens.any? { |n| ["不", "没"].includes?(n.token.try(&.text)) }

        if has_q_word
          leaf.vietnamese = "hả"
        elsif has_exclaim
          leaf.vietnamese = "biết bao"
          # "Duo...a" -> "biết bao". Clear "Duo".
          # "Tai...a" -> "Thật...a"? User didn't specify duplication.
          # "Duo niu bi a" -> "Ngau biet bao"
          # "Duo" -> "nhieu/biet bao".
          # Clear "Duo" if it's "多".
          # "Zhen" -> "that".
          tokens.each do |n|
            if n.token.try(&.text) == "多"
              n.vietnamese = ""
            end
          end
        elsif has_neg
          leaf.vietnamese = "mà"
        else
          leaf.vietnamese = "đấy"
        end
      end

      # 嘛
      private def handle_ma_tone(leaf : Node, parent : Node, index : Int32)
        tokens = parent.leaves
        full_text = tokens.map(&.token.try(&.text)).join.gsub("嘛", "")

        if full_text.starts_with?("这") # Zhege ma
          leaf.vietnamese = "thì"
        elsif full_text.includes?("帮") || full_text.includes?("求")
          leaf.vietnamese = "đi mà"
        else
          leaf.vietnamese = "mà" # Obvious
        end
      end

      # 呗
      private def handle_bei(leaf : Node, parent : Node, index : Int32)
        tokens = parent.leaves
        has_reluctant = tokens.any? { |n| ["只", "只能", "只好"].includes?(n.token.try(&.text)) }

        if has_reluctant
          leaf.vietnamese = "đành vậy"
        else
          leaf.vietnamese = "chứ sao"
        end
      end

      # 啦
      private def handle_la(leaf : Node, parent : Node, index : Int32)
        tokens = parent.leaves
        has_motion = tokens.any? { |n| ["走", "去", "快"].includes?(n.token.try(&.text)) }

        if has_motion && tokens.size < 5
          leaf.vietnamese = "thôi"
        else
          leaf.vietnamese = "đấy"
        end
      end
    end
  end
end
