require "./spec_helper"

describe Zh2Vi::Node do
  describe ".leaf" do
    it "creates a leaf node with token" do
      token = Zh2Vi::Token.new("我", "PN")
      node = Zh2Vi::Node.leaf("PN", token, 0)

      node.leaf?.should be_true
      node.phrase?.should be_false
      node.token.try(&.text).should eq("我")
      node.token.try(&.pos).should eq("PN")
      node.index.should eq(0)
    end
  end

  describe ".phrase" do
    it "creates a phrasal node with children" do
      child1 = Zh2Vi::Node.leaf("PN", Zh2Vi::Token.new("我", "PN"), 0)
      child2 = Zh2Vi::Node.leaf("VV", Zh2Vi::Token.new("爱", "VV"), 1)
      node = Zh2Vi::Node.phrase("VP", [child1, child2])

      node.phrase?.should be_true
      node.leaf?.should be_false
      node.children.size.should eq(2)
    end
  end

  describe ".entity" do
    it "creates an atomic NER node" do
      child = Zh2Vi::Node.leaf("NR", Zh2Vi::Token.new("北京", "NR"), 0)
      node = Zh2Vi::Node.entity("NP-GPE", [child])

      node.is_atomic?.should be_true
    end
  end

  describe "#leaves" do
    it "returns all leaf nodes in order" do
      # Build tree: (IP (NP (PN 我)) (VP (VV 爱) (NP (PN 你))))
      leaf1 = Zh2Vi::Node.leaf("PN", Zh2Vi::Token.new("我", "PN"), 0)
      leaf2 = Zh2Vi::Node.leaf("VV", Zh2Vi::Token.new("爱", "VV"), 1)
      leaf3 = Zh2Vi::Node.leaf("PN", Zh2Vi::Token.new("你", "PN"), 2)

      np1 = Zh2Vi::Node.phrase("NP", [leaf1])
      np2 = Zh2Vi::Node.phrase("NP", [leaf3])
      vp = Zh2Vi::Node.phrase("VP", [leaf2, np2])
      ip = Zh2Vi::Node.phrase("IP", [np1, vp])

      leaves = ip.leaves
      leaves.size.should eq(3)
      leaves[0].token.try(&.text).should eq("我")
      leaves[1].token.try(&.text).should eq("爱")
      leaves[2].token.try(&.text).should eq("你")
    end
  end

  describe "#text" do
    it "returns concatenated text of all leaves" do
      leaf1 = Zh2Vi::Node.leaf("PN", Zh2Vi::Token.new("我", "PN"), 0)
      leaf2 = Zh2Vi::Node.leaf("VV", Zh2Vi::Token.new("爱", "VV"), 1)
      leaf3 = Zh2Vi::Node.leaf("PN", Zh2Vi::Token.new("你", "PN"), 2)
      ip = Zh2Vi::Node.phrase("IP", [leaf1, leaf2, leaf3])

      ip.text.should eq("我爱你")
    end
  end

  describe "#head_child" do
    it "finds head of VP (left-to-right, VV priority)" do
      leaf1 = Zh2Vi::Node.leaf("AD", Zh2Vi::Token.new("很", "AD"), 0)
      leaf2 = Zh2Vi::Node.leaf("VV", Zh2Vi::Token.new("喜欢", "VV"), 1)
      vp = Zh2Vi::Node.phrase("VP", [leaf1, leaf2])

      head = vp.head_child
      head.should_not be_nil
      head.try(&.token).try(&.text).should eq("喜欢")
    end

    it "finds head of NP (right-to-left, NN priority)" do
      leaf1 = Zh2Vi::Node.leaf("JJ", Zh2Vi::Token.new("漂亮", "JJ"), 0)
      leaf2 = Zh2Vi::Node.leaf("NN", Zh2Vi::Token.new("书", "NN"), 1)
      np = Zh2Vi::Node.phrase("NP", [leaf1, leaf2])

      head = np.head_child
      head.should_not be_nil
      head.try(&.token).try(&.text).should eq("书")
    end
  end

  describe "#to_bracket" do
    it "outputs bracket notation" do
      leaf1 = Zh2Vi::Node.leaf("PN", Zh2Vi::Token.new("我", "PN"), 0)
      leaf2 = Zh2Vi::Node.leaf("VV", Zh2Vi::Token.new("爱", "VV"), 1)
      leaf3 = Zh2Vi::Node.leaf("PN", Zh2Vi::Token.new("你", "PN"), 2)

      np1 = Zh2Vi::Node.phrase("NP", [leaf1])
      np2 = Zh2Vi::Node.phrase("NP", [leaf3])
      vp = Zh2Vi::Node.phrase("VP", [leaf2, np2])
      ip = Zh2Vi::Node.phrase("IP", [np1, vp])

      bracket = ip.to_bracket
      bracket.should contain("(IP")
      bracket.should contain("(NP (PN 我))")
      bracket.should contain("(VP")
    end
  end

  describe "#traverse_postorder" do
    it "visits nodes in post-order" do
      leaf1 = Zh2Vi::Node.leaf("PN", Zh2Vi::Token.new("我", "PN"), 0)
      leaf2 = Zh2Vi::Node.leaf("VV", Zh2Vi::Token.new("爱", "VV"), 1)
      np = Zh2Vi::Node.phrase("NP", [leaf1])
      vp = Zh2Vi::Node.phrase("VP", [leaf2])
      ip = Zh2Vi::Node.phrase("IP", [np, vp])

      visited = [] of String
      ip.traverse_postorder do |node|
        visited << node.label
      end

      # Post-order: leaves first, then parents
      visited.should eq(["PN", "NP", "VV", "VP", "IP"])
    end
  end
end
