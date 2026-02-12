require "option_parser"
require "http/client"
require "json"
require "yaml"

# Define parsing structures matching HanLP response
struct HanLPResponse
  include JSON::Serializable
  @[JSON::Field(key: "tok/fine")]
  property tok : Array(Array(String))

  @[JSON::Field(key: "pos/ctb")]
  property pos : Array(Array(String))

  @[JSON::Field(key: "ner/ontonotes")]
  property ner : Array(Array(Array(JSON::Any)))

  property dep : Array(Array(Array(JSON::Any))) # [head_index, label]

  property con : Array(JSON::Any) # Constituency tree
end

# CLI Argument Parsing
group_name = ""
sentence = ""

OptionParser.parse do |parser|
  parser.banner = "Usage: gen_test [options]"
  parser.on("-g GROUP", "--group=GROUP", "Test group name (e.g., nouns, verbs)") { |g| group_name = g }
  parser.on("-s SENTENCE", "--sentence=SENTENCE", "Sentence to test") { |s| sentence = s }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
end

if group_name.empty? || sentence.empty?
  puts "Error: Both group and sentence are required."
  puts "Usage: crystal scripts/gen_test.cr -g <group> -s \"<sentence>\""
  exit 1
end

# HanLP Service Configuration
hanlp_host = "100.97.90.35"
hanlp_port = 5544
hanlp_path = "/ztxts/mtl_3"

# Call HanLP API
begin
  client = HTTP::Client.new(hanlp_host, hanlp_port)
  response = client.post(hanlp_path, body: sentence)

  unless response.success?
    puts "Error calling HanLP API: #{response.status_code} - #{response.body}"
    exit 1
  end

  hanlp_data = HanLPResponse.from_json(response.body)

  if hanlp_data.tok.empty?
    puts "Error: Empty token list from HanLP."
    exit 1
  end

  # Extract data for the first sentence (assuming single sentence input)
  toks = hanlp_data.tok[0]
  pos = hanlp_data.pos[0]
  ner = hanlp_data.ner[0]
  dep = hanlp_data.dep[0]
  con = hanlp_data.con[0]

  # Construct new test case
  # We construct a Hash to mimic the YAML structure
  new_tc = {
    "tok"      => JSON.parse(toks.to_json),
    "pos"      => JSON.parse(pos.to_json),
    "ner"      => JSON.parse(ner.to_json),
    "con"      => JSON.parse(con.to_json),
    "dep"      => JSON.parse(dep.to_json),
    "utt_dict" => [] of String,
    "drt_dict" => [] of String,
    "expected" => sentence, # Placeholder expected value
  }

  # File Handling
  output_dir = "spec/fixtures/pending"
  Dir.mkdir_p(output_dir)
  output_file = File.join(output_dir, "#{group_name}.yml")

  # Generate YAML for the new test case as a list item
  entry_yaml = [new_tc].to_yaml

  mode = (File.exists?(output_file) && File.size(output_file) > 0) ? "a" : "w"

  File.open(output_file, mode) do |f|
    lines = entry_yaml.lines
    if mode == "a"
      # If appending, we skip the first line if it is "---"
      if lines.first.strip == "---"
        lines.shift
      end
      f.puts lines.join("\n")
    else
      # Writing new file, keep the "---"
      f.puts entry_yaml
    end
  end

  puts "Successfully added test case to #{output_file}"
rescue ex : Exception
  puts "Error: #{ex.message}"
  ex.backtrace.each { |line| puts line }
  exit 1
end
