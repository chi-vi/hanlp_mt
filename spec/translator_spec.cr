require "./spec_helper"

describe Zh2Vi::Translator do
  describe ".default" do
    it "creates translator with default dictionaries" do
      translator = Zh2Vi::Translator.default
      translator.should_not be_nil
    end
  end

  describe ".load" do
    it "loads translator from data files" do
      translator = Zh2Vi::Translator.load(
        "data/pos-dict.jsonl",
        "data/dep-dict.jsonl"
      )
      translator.pos_dict.size.should be > 0
      translator.dep_dict.size.should be > 0
    end
  end

  describe "#translate" do
    it "translates simple sentence" do
      translator = Zh2Vi::Translator.load(
        "data/pos-dict.jsonl",
        "data/dep-dict.jsonl"
      )

      tree = translator.translate(
        "(IP (NP (PN 我)) (VP (VV 爱) (NP (PN 你))))",
        ["我", "爱", "你"],
        ["PN", "VV", "PN"]
      )

      leaves = tree.leaves
      leaves[0].vietnamese.should eq("tôi")
      leaves[1].vietnamese.should eq("yêu")
      leaves[2].vietnamese.should eq("bạn")
    end

    it "uses DEP for disambiguation" do
      translator = Zh2Vi::Translator.load(
        "data/pos-dict.jsonl",
        "data/dep-dict.jsonl"
      )

      dep_rels = [
        Zh2Vi::DepRel.new(0, 1, "root"),
        Zh2Vi::DepRel.new(1, 2, "dobj"),
      ]

      tree = translator.translate(
        "(VP (VV 打) (NP (NN 电话)))",
        ["打", "电话"],
        ["VV", "NN"],
        [] of Zh2Vi::NerSpan,
        dep_rels
      )

      leaves = tree.leaves
      # 打 with 电话 as dobj should be "gọi" not "đánh"
      leaves[0].vietnamese.should eq("gọi")
    end

    it "uses Hán-Việt for OOV proper nouns" do
      translator = Zh2Vi::Translator.default

      ner_spans = [Zh2Vi::NerSpan.new(0, 3, "PERSON")]

      tree = translator.translate(
        "(NP (NR 习) (NR 近) (NR 平))",
        ["习", "近", "平"],
        ["NR", "NR", "NR"],
        ner_spans
      )

      # Should use Hán-Việt conversion
      leaves = tree.leaves
      leaves[0].vietnamese.should_not be_nil
      leaves[0].vietnamese.not_nil!.should contain("Tập")
    end
  end

  describe "#output_text" do
    it "returns Vietnamese string" do
      translator = Zh2Vi::Translator.load(
        "data/pos-dict.jsonl",
        "data/dep-dict.jsonl"
      )

      tree = translator.translate(
        "(IP (NP (PN 我)) (VP (VV 爱) (NP (PN 你))))",
        ["我", "爱", "你"],
        ["PN", "VV", "PN"]
      )

      output = translator.output_text(tree)
      output.should contain("tôi")
      output.should contain("yêu")
      output.should contain("bạn")
    end
  end
end
