require "../node"

module Zh2Vi::Rules
  module Optative
    extend self

    def process(node : Node, future_ctx : Bool = false) : Node
      current_future = future_ctx

      # Flag to pass predictive context to the very next sibling (contextual trigger)
      next_child_predictive = false

      node.children.each_with_index do |child, idx|
        # Determine inherited context for this child
        child_ctx = current_future || next_child_predictive

        # Reset one-shot trigger
        next_child_predictive = false

        # Check if *this* child sets future context for *subsequent* siblings
        if is_future_or_predictive_marker?(child)
          current_future = true
          child_ctx = true # apply to self too
        end

        # Check if *this* child triggers predictive context for *next* sibling (e.g. "想" + Clause)
        if child.leaf? && child.token.try(&.text) == "想"
          # Look ahead
          next_sib = node.children[idx + 1]?
          if next_sib && (next_sib.label == "IP" || next_sib.label == "CP")
            next_child_predictive = true
          end
        end

        process(child, child_ctx)

        # Post-process Leaf Verbs
        if child.leaf? && child.token
          text = child.token.not_nil!.text

          if text == "会"
            if child_ctx
              child.vietnamese = "sẽ"
            else
              child.vietnamese = "biết"
            end
          elsif text == "想"
            process_xiang(child, node, idx)
          end
        end
      end

      node
    end

    private def process_xiang(node : Node, parent : Node, idx : Int32)
      siblings = parent.children
      next_sibling = siblings[idx + 1]?

      if next_sibling
        unwrapped = deep_unwrap(next_sibling)

        if is_noun_object?(unwrapped)
          node.vietnamese = "nhớ"
        elsif contains_future_marker?(next_sibling)
          node.vietnamese = "tưởng"
        elsif has_subject?(next_sibling)
          node.vietnamese = "tưởng"
        else
          node.vietnamese = "muốn"
        end
      else
        node.vietnamese = "muốn"
      end
    end

    private def deep_unwrap(node : Node) : Node
      curr = node
      counter = 0
      while (curr.label == "IP" || curr.label == "VP" || curr.label == "NP") && curr.children.size == 1
        curr = curr.children.first
        counter += 1
        break if counter > 10
      end
      curr
    end

    private def is_noun_object?(node : Node) : Bool
      # Check leaf POS
      return true if node.leaf? && (node.token.try(&.pos) == "NN" || node.token.try(&.pos) == "NR" || node.token.try(&.pos) == "PN" || node.token.try(&.pos) == "NT")
      # Check Phrasal Label
      return true if node.label == "NP" || node.label == "DP" || node.label == "QP"
      # Check NER entity (atomic node might not have token pos easily accessible if wrapped, but usually Leaf)
      # If atomic entity node (e.g. children are leaves):
      return true if node.is_atomic?
      false
    end

    private def has_subject?(node : Node) : Bool
      return false unless node.phrase?
      has_np = node.children.any? { |c| c.label == "NP" || c.label == "PN" || (c.leaf? && c.token.try(&.pos) == "PN") || (c.leaf? && c.token.try(&.pos) == "NR") }
      has_vp = node.children.any? { |c| c.label == "VP" || (c.leaf? && c.token.try(&.pos) == "VV") || c.label == "IP" }
      has_np && has_vp
    end

    private def is_future_or_predictive_marker?(node : Node) : Bool
      if node.leaf?
        text = node.token.try(&.text) || ""
        pos = node.token.try(&.pos)

        if pos == "NT" || pos == "AD" || pos == "DT" || pos == "M"
          return true if text.includes?("明")
          return true if text.includes?("下") && (text.includes?("周") || text.includes?("月"))
          return true if text.includes?("下") # Relaxed check for "下" as DT
          return true if text.includes?("将")
          return true if text == "待会儿" || text == "以后"
          return true if text.includes?("周") || text.includes?("月") || text.includes?("年") # "Next Week" -> "下" + "周"
        end

        return true if text == "一定" || text == "可能" || text == "大概" || text == "也许"

        return false
      else
        node.children.any? { |c| is_future_or_predictive_marker?(c) }
      end
    end

    private def contains_future_marker?(node : Node) : Bool
      if node.leaf?
        text = node.token.try(&.text) || ""
        return true if text == "会" || text == "将" || text == "要"
        return is_future_or_predictive_marker?(node)
      else
        node.children.any? { |c| contains_future_marker?(c) }
      end
    end
  end
end
