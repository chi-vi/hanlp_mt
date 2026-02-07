require "./spec_helper"

describe Zh2Vi::Parser do
  describe "#parse_con" do
    it "parses simple constituency tree" do
      parser = Zh2Vi::Parser.new
      tree = parser.parse_con("(IP (NP (PN 我)) (VP (VV 爱) (NP (PN 你))))")

      tree.label.should eq("IP")
      tree.children.size.should eq(2)
      tree.children[0].label.should eq("NP")
      tree.children[1].label.should eq("VP")
    end

    it "parses nested trees correctly" do
      parser = Zh2Vi::Parser.new
      tree = parser.parse_con("(NP (DNP (NP (NN 老师)) (DEG 的)) (NP (NN 书)))")

      tree.label.should eq("NP")
      tree.children.size.should eq(2)
      tree.children[0].label.should eq("DNP")
      tree.children[1].label.should eq("NP")
    end

    it "handles leaf nodes" do
      parser = Zh2Vi::Parser.new
      tree = parser.parse_con("(PN 我)")

      tree.leaf?.should be_true
      tree.token.try(&.text).should eq("我")
    end
  end

  describe "#parse" do
    it "integrates POS tags" do
      parser = Zh2Vi::Parser.new
      tree = parser.parse(
        "(IP (NP (PN 我)) (VP (VV 爱) (NP (PN 你))))",
        ["我", "爱", "你"],
        ["PN", "VV", "PN"]
      )

      leaves = tree.leaves
      leaves.size.should eq(3)
      leaves[0].token.try(&.pos).should eq("PN")
      leaves[1].token.try(&.pos).should eq("VV")
      leaves[2].token.try(&.pos).should eq("PN")
    end

    it "integrates NER spans" do
      parser = Zh2Vi::Parser.new
      ner_spans = [Zh2Vi::NerSpan.new(0, 2, "GPE")]

      tree = parser.parse(
        "(IP (NP (NR 北) (NR 京)) (VP (VV 大)))",
        ["北", "京", "大"],
        ["NR", "NR", "VV"],
        ner_spans
      )

      # The NP containing 北京 should be marked as atomic
      np = tree.children[0]
      np.is_atomic?.should be_true
      np.label.should contain("GPE")
    end

    it "integrates DEP relations" do
      parser = Zh2Vi::Parser.new
      dep_rels = [
        Zh2Vi::DepRel.new(2, 1, "nsubj"),
        Zh2Vi::DepRel.new(0, 2, "root"),
        Zh2Vi::DepRel.new(2, 3, "dobj"),
      ]

      tree = parser.parse(
        "(IP (NP (PN 我)) (VP (VV 爱) (NP (PN 你))))",
        ["我", "爱", "你"],
        ["PN", "VV", "PN"],
        [] of Zh2Vi::NerSpan,
        dep_rels
      )

      leaves = tree.leaves
      leaves[0].token.try(&.dep_rel).should eq("nsubj")
      leaves[0].token.try(&.dep_head).should eq(2)
    end
  end
end
