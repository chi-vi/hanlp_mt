require "../node"

module Zh2Vi::Rules
  # Reorder module contains rules for transforming Chinese tree structure
  # to Vietnamese word order
  module Reorder
    # Process a tree with all reordering rules (post-order traversal)
    def self.process(node : Node, dict : Dict::PosDict? = nil) : Node
      result = node.dup

      # Post-order: process children first, then this node
      result.children = result.children.map { |c| process(c, dict) }

      # Skip atomic nodes (NER entities)
      return result if result.is_atomic?

      # Apply reordering rules based on label
      case result.label
      when "NP"
        reorder_np(result)
      when "DNP"
        reorder_dnp(result)
      when "LCP"
        reorder_lcp(result)
      when "CP"
        reorder_cp(result)
      when "VP"
        process_vp(result, dict)
      when "QP"
        reorder_qp(result)
      else
        result
      end
    end

    # NP reordering: Chinese modifier-head -> Vietnamese head-modifier
    # Examples:
    # - 漂亮的книга -> sách đẹp
    # - DT + M + N -> N + M + DT (demonstratives to end)
    def self.reorder_np(node : Node) : Node
      return node if node.children.size < 2

      # Find demonstrative (DT/DP) at the beginning
      first = node.children.first
      if first.label == "DP" || first.token.try(&.pos) == "DT"
        # Move demonstrative to end
        rest = node.children[1..]
        node.children = rest + [first]
        return node
      end

      # Check for modifier + head patterns
      if node.children.size == 2
        left, right = node.children[0], node.children[1]
        left_pos = left.token.try(&.pos) || left.label
        right_pos = right.token.try(&.pos) || right.label

        # 1. Adjective + Noun -> Noun + Adjective
        # JJ/VA + NN/NP -> swap
        if (left_pos == "JJ" || left_pos == "VA") && (right_pos == "NN" || right_pos == "NP")
          node.children = [right, left]
          return node
        end

        # 2. Noun + Noun -> Noun + Noun (swap head)
        # NN/NR + NN/NP -> swap
        if (left_pos == "NN" || left_pos == "NR") && (right_pos == "NN" || right_pos == "NP")
          node.children = [right, left]
          return node
        end

        # 3. DNP + NP -> NP + DNP
        # Possessive/Attribute phrase -> move to back
        if left_pos == "DNP" && (right_pos == "NP" || right_pos == "NN")
          node.children = [right, left]
          return node
        end
      end

      node
    end

    # DNP reordering: Possessor + DEG + Noun -> Noun + của + Possessor
    # 老师的书 -> sách của thầy giáo
    def self.reorder_dnp(node : Node) : Node
      return node if node.children.size < 2

      # Find DEG node
      deg_idx = node.children.index { |c| c.token.try(&.pos) == "DEG" || c.label == "DEG" }
      return node unless deg_idx

      # Everything before DEG is possessor, DEG is connector
      possessor = node.children[0...deg_idx]
      deg = node.children[deg_idx]

      # Set Vietnamese for DEG
      deg.vietnamese = "của"

      # Reorder: DEG + Possessor
      # Chinese: Possessor + DEG (我 + 的)
      # Vietnamese: DEG + Possessor (của + tôi)
      node.children = [deg] + possessor
      node
    end

    # LCP reordering: NP + LC -> LC + NP (localizer phrase)
    # 桌子上 -> trên bàn
    def self.reorder_lcp(node : Node) : Node
      return node if node.children.size < 2

      # Find LC (localizer) - usually last child
      lc_idx = node.children.index { |c| c.token.try(&.pos) == "LC" || c.label == "LC" }
      return node unless lc_idx

      # Get the localizer and the rest
      lc = node.children[lc_idx]
      others = node.children.map_with_index { |c, i| i != lc_idx ? c : nil }.compact

      # Move LC to front
      node.children = [lc] + others
      node
    end

    # CP reordering: Relative clause + DEC + Head NP -> Head NP + mà + Clause
    # 我买的书 -> sách mà tôi mua
    def self.reorder_cp(node : Node) : Node
      return node if node.children.size < 2

      # Find DEC node
      dec_idx = node.children.index { |c| c.token.try(&.pos) == "DEC" || c.label == "DEC" }

      if dec_idx
        dec = node.children[dec_idx]
        dec.vietnamese = "mà"
      end

      # The actual reordering (CP before NP -> NP before CP) happens at parent level
      node
    end

    # VP processing: handle aspect markers, PP movement
    def self.process_vp(node : Node, dict : Dict::PosDict? = nil) : Node
      # Handle aspect markers (了, 着, 过) - move to front as adverbs
      process_aspect_markers(node, dict)

      # Handle QP modifier reordering (QP + VP -> VP + QP)
      reorder_modifier_qp(node)

      # Handle PP movement (PP before V -> V before PP)
      move_pp_to_end(node)

      node
    end

    # Move aspect markers (AS) to front of VP as adverbs OR keep at end based on translation
    # V + 了 -> đã + V (if translated as 'đã')
    # V + 了 -> V + rồi (if translated as 'rồi')
    private def self.process_aspect_markers(node : Node, dict : Dict::PosDict? = nil) : Node
      as_idx = node.children.index { |c| c.token.try(&.pos) == "AS" }
      return node unless as_idx

      as_node = node.children[as_idx]
      as_text = as_node.token.try(&.text)
      return node unless as_text

      # 1. Check dictionary first if available
      vn_adv = nil
      placement = :front # :front (before V) or :back (after V/Obj)

      if dict
        # Try lookup
        if vn_adv = dict.lookup(as_text, "AS")
          # Heuristic: 'rồi' -> back, 'đã'/'đang' -> front
          if vn_adv == "rồi"
            placement = :back
          else
            placement = :front
          end

          # We can set the translation here to ensure consistency
          as_node.vietnamese = vn_adv
        end
      end

      # 2. Fallback to hardcoded rules if no dict match or no dict provided
      unless vn_adv
        vn_adv = case as_text
                 when "了" then "đã"
                 when "着" then "đang"
                 when "过" then "đã từng"
                 else          nil
                 end
        placement = :front
        as_node.vietnamese = vn_adv if vn_adv
      end

      return node unless vn_adv

      # Remove AS from current position
      others = node.children.map_with_index { |c, i| i != as_idx ? c : nil }.compact

      if placement == :front
        # Find verb position and insert before it
        verb_idx = others.index { |c|
          pos = c.token.try(&.pos) || c.label
          pos.starts_with?("V")
        }

        if verb_idx
          node.children = others[0...verb_idx] + [as_node] + others[verb_idx..]
        else
          node.children = [as_node] + others
        end
      else
        # Placement :back - move to end
        node.children = others + [as_node]
      end

      node
    end

    # Move PP (prepositional phrase) to after VP
    # PP + V -> V + PP
    private def self.move_pp_to_end(node : Node) : Node
      # Find PP that should be moved (location/instrument PPs)
      pp_indices = [] of Int32
      node.children.each_with_index do |child, i|
        if child.label == "PP"
          # Check if it's a location PP (在, 于, 往, 向, 自)
          first_leaf = child.leaves.first?
          if first_leaf
            prep = first_leaf.token.try(&.text)
            if prep && {"在", "于", "往", "向", "自"}.includes?(prep)
              pp_indices << i
            end
          end
        end
      end

      return node if pp_indices.empty?

      # Collect PPs to move
      pps_to_move = pp_indices.map { |i| node.children[i] }

      # Remove PPs from current positions
      remaining = node.children.map_with_index { |c, i| !pp_indices.includes?(i) ? c : nil }.compact

      # Append PPs at the end
      node.children = remaining + pps_to_move
      node
    end

    # QP reordering: Handle demonstrative in quantity phrases
    # 这三本书 -> ba cuốn sách này
    def self.reorder_qp(node : Node) : Node
      # Check for DT at beginning
      dt_idx = node.children.index { |c| c.token.try(&.pos) == "DT" }
      return node unless dt_idx && dt_idx == 0

      # Move DT to end
      dt = node.children[0]
      rest = node.children[1..]
      node.children = rest + [dt]
      node
    end

    # QP modifier reordering: QP + VP -> VP + QP
    # Five feet tall -> Tall five feet
    # 五尺 (QP) + 高 (VP/VA) -> 高 (VP/VA) + 五尺 (QP)
    def self.reorder_modifier_qp(node : Node) : Node
      return node if node.children.size != 2

      left, right = node.children[0], node.children[1]

      # Check for QP + VP pattern
      if left.label == "QP" && right.label == "VP"
        node.children = [right, left]
        return node
      end

      node
    end
  end
end
