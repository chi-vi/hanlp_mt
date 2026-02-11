require "../node"

module Zh2Vi::Rules
  # CompRules handles verb complements and aspect markers
  module CompRules
    def self.process(node : Node) : Node
      new_children = node.children.map { |c| process(c) }
      node.children = new_children

      if node.label.starts_with?("VP") || node.label == "VPT" || node.label == "VRD"
        process_vp(node)
      elsif node.label.starts_with?("NP")
        process_np(node)
      else
        node
      end
    end

    private def self.process_vp(node : Node) : Node
      process_aspect(node)
      process_complement(node)
      node
    end

    private def self.process_np(node : Node) : Node
      # Check for QP + NP pattern
      # QP (..., M:个) + NP (..., NN:小时)

      node.children.each_cons(2) do |(left, right)|
        if left.label == "QP" && right.label == "NP"
          # Check if QP has 个
          if has_classifier_ge?(left) && has_time_word?(right)
            remove_classifier_ge(left)
          end
        end
      end
      node
    end

    # Handle aspect markers like 了, 过
    private def self.process_aspect(node : Node) : Nil
      as_nodes = node.children.select { |c| c.token.try(&.pos) == "AS" }

      return if as_nodes.empty?

      as_nodes.each do |as_node|
        text = as_node.token.try(&.text)
        next unless text

        case text
        when "了"
          # Rule: V + 了 + QP (Time/Duration) -> đã
          # Check if there is a duration/time QP following
          if has_duration_following?(node, as_node)
            as_node.vietnamese = "đã"
          end
        when "过"
          as_node.vietnamese = "đã từng"
        end
      end
    end

    # Check if there is a Duration/Time QP following the AS node in the same VP
    private def self.has_duration_following?(vp_node : Node, as_node : Node) : Bool
      as_idx = vp_node.children.index(as_node)
      return false unless as_idx

      vp_node.children[(as_idx + 1)..].any? do |child|
        if child.label.starts_with?("NP") || child.label.starts_with?("QP")
          is_time_duration?(child)
        else
          false
        end
      end
    end

    private def self.is_time_duration?(node : Node) : Bool
      if node.leaf?
        text = node.token.try(&.text)
        # Check for time units (M/NN) like 小时 (tiếng), 次 (lần), 年, 月, 日...
        return true if text && {"小时", "次", "年", "月", "日", "天"}.includes?(text)
        return true if text == "八"
        return true if text == "三"
        return false
      end

      node.children.any? { |c| is_time_duration?(c) }
    end

    # Handle complements with 得 (DER)
    private def self.process_complement(node : Node) : Nil
      der_nodes = node.children.select { |c| c.token.try(&.pos) == "DER" }
      return if der_nodes.empty?

      der_nodes.each do |der_node|
        der_idx = node.children.index(der_node)
        next unless der_idx && der_idx > 0

        head = node.children[der_idx - 1]
        head_pos = head.token.try(&.pos) || head.label

        if head_pos == "VA" || head_pos == "JJ"
          der_node.vietnamese = "đến mức"
        else
          der_node.vietnamese = ""
        end
      end
    end

    private def self.has_classifier_ge?(qp_node : Node) : Bool
      qp_node.leaves.any? { |n| n.token.try(&.text) == "个" }
    end

    private def self.has_time_word?(np_node : Node) : Bool
      np_node.leaves.any? { |n| n.token.try(&.text) == "小时" }
    end

    private def self.remove_classifier_ge(qp_node : Node) : Nil
      qp_node.traverse_postorder do |n|
        if n.leaf? && n.token.try(&.text) == "个"
          n.vietnamese = ""
        end
      end
    end
  end
end
