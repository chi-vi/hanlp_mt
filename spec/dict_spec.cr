require "./spec_helper"

describe Zh2Vi::Dict::PosDict do
  describe ".load" do
    it "loads dictionary from JSONL file" do
      dict = Zh2Vi::Dict::PosDict.load("data/pos-dict.jsonl")
      dict.size.should be > 0
    end
  end

  describe "#lookup" do
    it "returns translation when both tok and pos match" do
      dict = Zh2Vi::Dict::PosDict.new
      # UTT tags: F (function word for LC), V (verb for VV), N (noun for NN)
      dict.add("上", "F", "trên") # LC -> F
      dict.add("上", "V", "lên")  # VV -> V

      # lookup converts POS -> UTT internally
      dict.lookup("上", "LC").should eq("trên") # LC -> F
      dict.lookup("上", "VV").should eq("lên")  # VV -> V
      dict.lookup("上", "NN").should be_nil     # NN -> N, no entry
    end
  end

  describe "#lookup_any" do
    it "returns any translation for tok" do
      dict = Zh2Vi::Dict::PosDict.new
      dict.add("书", "NN", "sách")

      dict.lookup_any("书").should eq("sách")
      dict.lookup_any("xyz").should be_nil
    end
  end
end

describe Zh2Vi::Dict::DepDict do
  describe ".load" do
    it "loads dictionary from JSONL file" do
      dict = Zh2Vi::Dict::DepDict.load("data/dep-dict.jsonl")
      dict.size.should be > 0
    end
  end

  describe "#lookup" do
    it "returns exact match" do
      dict = Zh2Vi::Dict::DepDict.new
      dict.add("打", "电话", "dobj", "gọi", "điện thoại")

      match = dict.lookup("打", "电话", "dobj")
      match.should_not be_nil
      match.try(&.child_val).should eq("gọi")
      match.try(&.parent_val).should eq("điện thoại")
    end

    it "matches suffix wildcard pattern" do
      dict = Zh2Vi::Dict::DepDict.new
      dict.add("开", "*门", "dobj", "mở", nil)

      match = dict.lookup("开", "大门", "dobj")
      match.should_not be_nil
      match.try(&.child_val).should eq("mở")
      match.try(&.parent_val).should be_nil
    end

    it "matches prefix wildcard pattern" do
      dict = Zh2Vi::Dict::DepDict.new
      dict.add("上", "学*", "nmod", "đi học", nil)

      match = dict.lookup("上", "学校", "nmod")
      match.should_not be_nil
      match.try(&.child_val).should eq("đi học")
    end

    it "matches deprel wildcard" do
      dict = Zh2Vi::Dict::DepDict.new
      dict.add("打", "*", "*", "đánh", nil)

      match = dict.lookup("打", "任何", "any_rel")
      match.should_not be_nil
      match.try(&.child_val).should eq("đánh")
    end

    it "prefers exact match over wildcard" do
      dict = Zh2Vi::Dict::DepDict.new
      dict.add("打", "电话", "dobj", "gọi", "điện thoại")
      dict.add("打", "*", "*", "đánh", nil)

      match = dict.lookup("打", "电话", "dobj")
      match.should_not be_nil
      match.try(&.child_val).should eq("gọi")
    end
  end
end

describe Zh2Vi::Dict::HanViet do
  describe ".default" do
    it "creates dictionary with common mappings" do
      dict = Zh2Vi::Dict::HanViet.default
      dict.size.should be > 0
    end
  end

  describe "#convert" do
    it "converts Chinese characters to Hán-Việt" do
      dict = Zh2Vi::Dict::HanViet.default

      dict.convert_char('大').should eq("đại")
      dict.convert_char('学').should eq("học")
    end

    it "converts string to Sino-Vietnamese" do
      dict = Zh2Vi::Dict::HanViet.default

      result = dict.convert("大学")
      result.should contain("Đại")
      result.should contain("Học")
    end
  end

  describe "#convert_proper" do
    it "capitalizes all words for proper nouns" do
      dict = Zh2Vi::Dict::HanViet.default

      result = dict.convert_proper("习近平")
      result.should contain("Tập")
      result.should contain("Cận")
      result.should contain("Bình")
    end
  end
end
