require "yaml"
require "json"
require "http/client"

# POS to UTT mapping based on doc/unified-tagset.md
def pos_to_utt(pos : String) : String
  case pos
  when "NN", "NT"       then "N"
  when "VV", "VC", "VE" then "V"
  when "JJ", "VA"       then "A"
  when "AD"             then "D"
  when "M", "CD", "OD"  then "M"
  when "NR"             then "NR"
  when "PN", "DT"       then "PN"
  when "IJ", "ON", "SP" then "I"
  when "P", "DEC", "DEG", "DER", "DEV", "AS", "MSP",
       "LC", "BA", "SB", "LB", "ETC" then "F"
  else "X"
  end
end

def ner_to_utt(ner : String) : String
  case ner
  when "PERSON", "ORG", "GPE", "LOCATION",
       "FACILITY", "NORP" then "NR"
  when "PRODUCT", "EVENT", "WORK_OF_ART",
       "LAW", "DATE", "TIME" then "N"
  when "PERCENT", "MONEY", "QUANTITY",
       "ORDINAL", "CARDINAL" then "M"
  else "X"
  end
end

# Define parsing structures
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

# Main processing logic
source_dir = "doc/older-tests/grammar"
output_dir = "spec/fixtures/grammar"

# Ensure output directory exists
Dir.mkdir_p(output_dir)

client = HTTP::Client.new("100.97.90.35", 5544)

# Get all YAML files
files = Dir.glob(File.join(source_dir, "*.yml"))
puts "Found #{files.size} files to migrate."

files.each do |input_path|
  filename = File.basename(input_path)
  output_path = File.join(output_dir, filename)

  puts "Migrating #{filename}..."

  unless File.exists?(input_path)
    puts "Error: Input file not found: #{input_path}"
    next
  end

  raw_content = File.read(input_path)
  begin
    test_cases = YAML.parse(raw_content).as_a
  rescue e : TypeCastError
    puts "Skipping #{filename}: content is not a list (possibly empty or different format)."
    next
  rescue e : YAML::ParseException
    puts "Skipping #{filename}: invalid YAML."
    next
  end

  new_test_cases = [] of Hash(String, JSON::Any)

  test_cases.each do |tc|
    # Handle cases where input might be missing or different structure
    unless tc.as_h.has_key?("input") && tc.as_h.has_key?("expected")
      puts "Skipping a test case in #{filename}: missing 'input' or 'expected' field."
      next
    end

    input_text = tc["input"].as_s
    expected = tc["expected"].as_s
    old_dict = tc["dict"]? ? tc["dict"].as_h : Hash(YAML::Any, YAML::Any).new

    # puts "  Processing: #{input_text}"

    # Call HanLP API
    response = client.post("/ztxts/mtl_3", body: input_text)

    unless response.success?
      puts "  Error calling HanLP API for '#{input_text}': #{response.status_code}"
      next
    end

    begin
      hanlp_data = HanLPResponse.from_json(response.body)
    rescue e : JSON::ParseException
      puts "  Error parsing JSON response for '#{input_text}': #{e.message}"
      # puts "  Response body: #{response.body}"
      next
    end

    if hanlp_data.tok.empty?
      puts "  Warning: Empty token list from HanLP for '#{input_text}'"
      next
    end

    # We assume single sentence input for now, so take the first element
    toks = hanlp_data.tok[0]
    pos = hanlp_data.pos[0]
    ner = hanlp_data.ner[0]
    dep = hanlp_data.dep[0]
    con = hanlp_data.con[0]

    # Build utt_dict
    utt_dict = [] of Array(String)

    toks.each_with_index do |token, idx|
      # Check if token exists in old dict
      translation = nil
      old_dict.each do |k, v|
        # Handle YAML keys which might be strings or other types
        k_str = k.as_s? || k.to_s
        if k_str == token
          translation = v.as_s? || v.to_s
          break
        end
      end

      if translation
        tag = pos_to_utt(pos[idx])
        utt_dict << [token, tag, translation]
      end
    end

    # Construct new test case
    new_tc = {
      "tok"      => JSON.parse(toks.to_json),
      "pos"      => JSON.parse(pos.to_json),
      "ner"      => JSON.parse(ner.to_json),
      "con"      => JSON.parse(con.to_json),
      "dep"      => JSON.parse(dep.to_json),
      "utt_dict" => JSON.parse(utt_dict.to_json),
      "drt_dict" => JSON.parse(([] of String).to_json),
      "expected" => JSON.parse(expected.to_json),
    }

    new_test_cases << new_tc
  end

  # Write to output file
  File.open(output_path, "w") do |f|
    f.puts new_test_cases.to_yaml
  end

  puts "  -> Processed #{new_test_cases.size} cases."
end

puts "Migration complete."
