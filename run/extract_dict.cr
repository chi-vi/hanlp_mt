#!/usr/bin/env crystal
# Extract Gemini output JSON files to JSONL format
# Input: directory containing .json files (Gemini API response)
# Output: .out files (JSONL, each line is [tok, pku, utt, val])

require "json"
require "./mapping"

# Parse markdown table from Gemini response
def parse_table(content : String) : Array(Array(String))
  results = [] of Array(String)

  content.each_line do |line|
    line = line.strip
    # Skip header rows and separator rows
    next if line.empty?
    next if line.starts_with?("|---") || line.starts_with?("|:--")
    next if line.includes?("Cụm từ") || line.includes?("Từ loại")

    # Parse table row: | tok | pku | val |
    if line.starts_with?("|") && line.ends_with?("|")
      cols = line.split("|").map(&.strip)
      # cols[0] = "", cols[1] = tok, cols[2] = pku, cols[3] = val, cols[4] = ""
      if cols.size >= 4
        tok = cols[1]
        pku = cols[2]
        val = cols[3]

        next if tok.empty? || pku.empty?

        utt = PKU2UTT.convert(pku)
        results << [tok, pku, utt, val]
      end
    end
  end

  results
end

# Extract from single JSON file
def extract_file(json_path : String) : Array(Array(String))
  json = JSON.parse(File.read(json_path))

  # Get content from Gemini response
  content = json.dig?("choices", 0, "message", "content")
  return [] of Array(String) unless content

  parse_table(content.as_s)
end

# Process directory
def process_directory(dir : String)
  Dir.glob(File.join(dir, "*.json")).each do |json_path|
    puts "Processing: #{json_path}"

    results = extract_file(json_path)
    if results.empty?
      puts "  Warning: No data extracted"
      next
    end

    # Write to .out file (JSONL format)
    out_path = json_path.sub(/\.json$/, ".out")
    File.open(out_path, "w") do |f|
      results.each do |row|
        f.puts row.to_json
      end
    end

    puts "  Extracted #{results.size} entries -> #{out_path}"
  end
end

# Main
if ARGV.empty?
  puts "Usage: #{PROGRAM_NAME} <directory>"
  puts "  Extracts Gemini API JSON responses to JSONL format"
  puts "  Output: [tok, pku, utt, val] per line"
  exit 1
end

dir = ARGV[0]
unless Dir.exists?(dir)
  puts "Error: Directory not found: #{dir}"
  exit 1
end

process_directory(dir)
