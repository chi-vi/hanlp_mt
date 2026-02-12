require "yaml"
require "json"

sentences = {
  "我吃饭了"   => "Tôi ăn cơm rồi",
  "下雨了"    => "Mưa rồi",
  "太好了"    => "Tốt quá",
  "你去吗"    => "Bạn đi không",
  "你吃饭了吗"  => "Bạn ăn cơm chưa",
  "是这样吗"   => "Đúng là vậy à",
  "这个吗"    => "Cái này thì",
  "谁呢"     => "Ai thế",
  "怎么还没好呢" => "Sao vẫn chưa tốt vậy",
  "他在睡觉呢"  => "Anh ấy đang ngủ đấy",
  "时间还早呢"  => "Thời gian vẫn sớm đấy",
  "我才不去呢"  => "Tôi mới không đi đâu",
  "我们走吧"   => "Chúng ta đi nhé",
  "快点吧"    => "Nhanh chút đi",
  "是他吧"    => "Là anh ấy chắc",
  "好吧"     => "Tốt thôi",
  "是这样吧"   => "Là vậy nhỉ",
  "多好啊"    => "Tốt biết bao",
  "你说什么啊"  => "Bạn nói cái gì hả",
  "小心啊"    => "Cẩn thận đấy",
  "我没说啊"   => "Tôi chưa nói mà",
  "你知道的嘛"  => "Bạn biết đấy mà",
  "帮帮我嘛"   => "Giúp tôi đi mà",
  "这个嘛"    => "Cái này thì",
  "不懂就问呗"  => "Không hiểu thì hỏi chứ sao",
  "只能这样呗"  => "Chỉ có thể vậy đành vậy",
  "只是玩笑罢了" => "Chỉ là đùa thôi",
  "不过如此而已" => "Cũng như vậy mà thôi",
  "我是昨天来的" => "Tôi đúng là hôm qua đến đấy",
  "他来啦"    => "Anh ấy đến đấy",
  "走啦"     => "Đi thôi",
  "好耶"     => "Tốt nha",
}

# Strict default meanings as requested
dict_map = {
  "我"      => {"PN" => "tôi", "RR" => "tôi"},
  "吃饭"     => {"VV" => "ăn cơm"},
  "下雨"     => {"VV" => "mưa"},
  "太"      => {"AD" => "quá"},
  "好"      => {"VA" => "tốt", "JJ" => "tốt"},
  "好吧"     => {"SP" => "Tốt thôi"},
  "不过如此而已" => {"VV" => "Cũng như vậy mà thôi", "ID" => "Cũng như vậy mà thôi"},
  "我是昨天来的" => {"VV" => "Tôi đúng là hôm qua đến đấy"},
  "你"      => {"PN" => "bạn"},
  "去"      => {"VV" => "đi"},
  "是"      => {"VC" => "là"},
  "这样"     => {"VV" => "vậy", "PN" => "vậy", "VA" => "vậy"},
  "这个"     => {"PN" => "cái này", "DT" => "cái này"},
  "这"      => {"DT" => "này", "PN" => "đây"},
  "个"      => {"M" => "cái"},
  "谁"      => {"PN" => "ai"},
  "怎么"     => {"AD" => "sao"},
  "还"      => {"AD" => "vẫn", "d" => "còn"},
  "没"      => {"AD" => "chưa", "d" => "không"},
  "在"      => {"P" => "ở", "AD" => "đang"},
  "睡觉"     => {"VV" => "ngủ"},
  "时间"     => {"NN" => "thời gian"},
  "早"      => {"VA" => "sớm"},
  "才"      => {"AD" => "mới"},
  "不"      => {"AD" => "không"},
  "我们"     => {"PN" => "chúng ta"},
  "走"      => {"VV" => "đi"},
  "快点"     => {"VV" => "nhanh lên", "AD" => "nhanh lên"},
  "快"      => {"VA" => "nhanh"},
  "点"      => {"M" => "chút", "VV" => "lên"},
  "他"      => {"PN" => "anh ấy"},
  "多"      => {"AD" => "biết bao", "VA" => "nhiều"},
  "说"      => {"VV" => "nói"},
  "什么"     => {"PN" => "cái gì"},
  "小心"     => {"VA" => "cẩn thận"},
  "知道"     => {"VV" => "biết"},
  "帮帮"     => {"VV" => "giúp"},
  "懂"      => {"VV" => "hiểu"},
  "就"      => {"AD" => "thì"},
  "问"      => {"VV" => "hỏi"},
  "只能"     => {"VV" => "chỉ có thể"},
  "只是"     => {"AD" => "chỉ là"},
  "玩笑"     => {"NN" => "đùa", "n" => "trò đùa"},
  "不过"     => {"AD" => "cũng"},
  "如此"     => {"VV" => "như vậy"},
  "昨天"     => {"NT" => "hôm qua"},
  "来"      => {"VV" => "đến"},
  "只"      => {"AD" => "chỉ"},
  "能"      => {"VV" => "có thể"},
  "如此而已"   => {"VV" => "như vậy mà thôi", "ID" => "như vậy mà thôi"},

  # Strict Particle Defaults
  "了"  => {"SP" => "rồi", "AS" => "rồi"},
  "吗"  => {"SP" => "không"},
  "呢"  => {"SP" => "nhỉ"}, # Changed from "thế"
  "吧"  => {"SP" => "nhé"},
  "啊"  => {"SP" => "à"}, # Changed from "a"
  "嘛"  => {"SP" => "mà"},
  "呗"  => {"SP" => "thôi"},    # Changed from "chứ sao"
  "罢了" => {"SP" => "mà thôi"}, # Changed from "thôi"
  "而已" => {"SP" => "thôi"},    # Changed from "mà thôi"
  "的"  => {"SP" => "đấy", "DEC" => "của", "DEG" => "của", "DEV" => "mà"},
  "啦"  => {"SP" => "đấy"},
  "耶"  => {"SP" => "nha"},
}

input_file = "spec/fixtures/grammar/sentence_particles.yml"
output_file = "spec/fixtures/grammar/sentence_particles.yml"

if !File.exists?(input_file)
  puts "Input file not found: #{input_file}"
  exit 1
end

raw_yaml = File.read(input_file)
parsed_data = Array(Hash(String, YAML::Any)).from_yaml(raw_yaml)

processed_data = parsed_data.map do |tc|
  toks = tc["tok"].as_a.map(&.as_s)
  postags = tc["pos"].as_a.map(&.as_s)
  raw_sentence = toks.join

  utt_dict = [] of Array(String)

  toks.each_with_index do |word, i|
    tag = postags[i]
    meaning = ""
    if dict_map.has_key?(word)
      entry = dict_map[word]
      meaning = entry[tag]? || entry.values.first? || ""
    else
      puts "Missing dictionary entry for: #{word}"
    end

    if !meaning.empty?
      utt_dict << [word, tag, meaning]
    end
  end

  expected_val = sentences[raw_sentence]? || tc["expected"].as_s
  expected_val = expected_val.downcase

  new_tc = Hash(String, YAML::Any).new
  new_tc["tok"] = tc["tok"]
  new_tc["pos"] = tc["pos"]
  new_tc["ner"] = tc["ner"]
  new_tc["con"] = tc["con"]
  new_tc["dep"] = tc["dep"]

  utt_dict_yaml = YAML::Any.new(
    utt_dict.map do |entry|
      YAML::Any.new(
        entry.map { |s| YAML::Any.new(s) }
      )
    end
  )
  new_tc["utt_dict"] = utt_dict_yaml

  new_tc["drt_dict"] = tc["drt_dict"]
  new_tc["expected"] = YAML::Any.new(expected_val)

  new_tc
end

File.open(output_file, "w") do |f|
  f.puts processed_data.to_yaml
end

puts "Processed #{processed_data.size} items."
