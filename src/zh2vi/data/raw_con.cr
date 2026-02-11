require "json"
require "yaml"

class Zh2Vi::RawCon
  include JSON::Serializable
  include YAML::Serializable

  getter cpos : String
  getter body : String | Array(RawCon)

  def self.new(pull : JSON::PullParser)
    pull.max_nesting = 9999
    queue = [] of self

    loop do
      pull.read_begin_array
      cpos = pull.read_string
      pull.read_begin_array

      if pull.kind.begin_array?
        node = new(cpos, [] of self)
        if last = queue.last?
          last.body.as(Array) << node
        end

        queue << node
        next
      end

      body = pull.read_string
      pull.read_end_array
      pull.read_end_array

      node = new(cpos, body)
      # for special cases e.g `(OD 第１)`
      return node unless last = queue.last?
      last.body.as(Array) << node

      while pull.kind.end_array?
        pull.read_end_array
        pull.read_end_array
        last = queue.pop
        return last if queue.empty?
      end
    end

    queue.last
  end

  def self.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
    unless node.is_a?(YAML::Nodes::Sequence)
      node.raise "Expected sequence for RawCon"
    end

    seq = node.as(YAML::Nodes::Sequence)
    if seq.nodes.size < 2
      node.raise "Expected [cpos, body]"
    end

    cpos_node = seq.nodes[0]
    unless cpos_node.is_a?(YAML::Nodes::Scalar)
      cpos_node.raise "Expected String for cpos"
    end
    cpos = cpos_node.value

    body_node = seq.nodes[1]

    if body_node.is_a?(YAML::Nodes::Scalar)
      # Leaf: [Label, Text]
      new(cpos, body_node.value)
    elsif body_node.is_a?(YAML::Nodes::Sequence)
      # Check if it's [Text] (Leaf node where body is a list containing one string)
      if body_node.nodes.size == 1 && body_node.nodes[0].is_a?(YAML::Nodes::Scalar)
        new(cpos, body_node.nodes[0].as(YAML::Nodes::Scalar).value)
      else
        # Branch: [Label, [Child1, Child2]]
        children = [] of RawCon
        body_node.nodes.each do |child_node|
          children << RawCon.new(ctx, child_node)
        end
        new(cpos, children)
      end
    else
      node.raise "Invalid body type"
    end
  end

  def initialize(@cpos, @body = "")
  end

  def to_json(json : JSON::Builder)
    json.max_nesting = 9999

    json.start_array
    json.string @cpos
    json.start_array

    case body = @body
    in String then json.string body
    in Array  then body.each(&.to_json(json))
    end

    json.end_array
    json.end_array
  end

  def to_bracket(io : IO) : Nil
    io << '(' << @cpos

    case body = @body
    when String
      io << ' ' << body
    else
      body.each do |child|
        io << ' '
        child.to_bracket(io)
      end
    end

    io << ')'
  end
end
