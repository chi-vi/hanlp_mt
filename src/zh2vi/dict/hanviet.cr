module Zh2Vi::Dict
  # HanViet converts Chinese characters to Sino-Vietnamese (Hán-Việt) readings
  # Used for OOV (Out-of-Vocabulary) words, especially proper nouns
  class HanViet
    @data : Hash(Char, String)

    def initialize
      @data = Hash(Char, String).new
    end

    # Load from file: each line is "char reading" or "char\treading"
    def self.load(path : String) : HanViet
      dict = HanViet.new
      File.each_line(path) do |line|
        line = line.strip
        next if line.empty? || line.starts_with?('#')

        parts = line.split(/[\t ]/, 2)
        next unless parts.size >= 2

        char = parts[0]
        reading = parts[1].strip
        next if char.empty? || reading.empty?

        # Only take the first character
        dict.add(char[0], reading)
      end
      dict
    end

    # Create with common Sino-Vietnamese mappings (built-in fallback)
    def self.default : HanViet
      dict = HanViet.new
      # Common characters - this is a minimal set for demo
      {
        '我' => "ngã",
        '你' => "nhĩ",
        '他' => "tha",
        '她' => "tha",
        '它' => "tha",
        '的' => "đích",
        '是' => "thị",
        '在' => "tại",
        '有' => "hữu",
        '这' => "giá",
        '那' => "na",
        '不' => "bất",
        '了' => "liễu",
        '人' => "nhân",
        '大' => "đại",
        '小' => "tiểu",
        '中' => "trung",
        '国' => "quốc",
        '上' => "thượng",
        '下' => "hạ",
        '前' => "tiền",
        '后' => "hậu",
        '左' => "tả",
        '右' => "hữu",
        '东' => "đông",
        '西' => "tây",
        '南' => "nam",
        '北' => "bắc",
        '京' => "kinh",
        '学' => "học",
        '校' => "hiệu",
        '生' => "sinh",
        '习' => "tập",
        '近' => "cận",
        '平' => "bình",
        '书' => "thư",
        '读' => "độc",
        '写' => "tả",
        '说' => "thuyết",
        '话' => "thoại",
        '文' => "văn",
        '字' => "tự",
        '年' => "niên",
        '月' => "nguyệt",
        '日' => "nhật",
        '时' => "thời",
        '分' => "phân",
        '秒' => "miểu",
        '一' => "nhất",
        '二' => "nhị",
        '三' => "tam",
        '四' => "tứ",
        '五' => "ngũ",
        '六' => "lục",
        '七' => "thất",
        '八' => "bát",
        '九' => "cửu",
        '十' => "thập",
        '百' => "bách",
        '千' => "thiên",
        '万' => "vạn",
        '亿' => "ức",
        '公' => "công",
        '司' => "ty",
        '银' => "ngân",
        '行' => "hành",
        '复' => "phục",
        '旦' => "đán",
        '美' => "mỹ",
        '德' => "đức",
        '法' => "pháp",
        '英' => "anh",
        '俄' => "nga",
        '日' => "nhật",
        '韩' => "hàn",
        '越' => "việt",
        '华' => "hoa",
        '看' => "khán",
        '见' => "kiến",
        '听' => "thính",
        '懂' => "hiểu",
        '买' => "mãi",
        '到' => "đáo",
        '完' => "hoàn",
        '错' => "thác",
        '很' => "hận",
        '好' => "hảo",
        '吃' => "cật",
        '饭' => "phạn",
        '桌' => "trác",
        '子' => "tử",
        '家' => "gia",
        '里' => "lý",
        '这' => "giá",
        '本' => "bản",
      }.each { |k, v| dict.add(k, v) }
      dict
    end

    def add(char : Char, reading : String) : Nil
      @data[char] = reading
    end

    # Convert a single character
    def convert_char(char : Char) : String?
      @data[char]?
    end

    # Convert a string of Chinese characters to Sino-Vietnamese
    # Unknown characters are kept as-is
    def convert(text : String) : String
      String.build do |io|
        text.each_char_with_index do |char, i|
          if reading = @data[char]?
            # Capitalize first letter of proper nouns
            io << " " if i > 0
            io << reading.capitalize
          else
            io << char
          end
        end
      end.strip
    end

    # Convert for proper nouns (all words capitalized)
    def convert_proper(text : String) : String
      result = [] of String
      text.each_char do |char|
        if reading = @data[char]?
          result << reading.capitalize
        else
          result << char.to_s
        end
      end
      result.join(" ")
    end

    def size : Int32
      @data.size
    end

    def has_key?(char : Char) : Bool
      @data.has_key?(char)
    end
  end
end
