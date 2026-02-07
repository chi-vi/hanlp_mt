require "./spec_helper"

describe Zh2Vi::Rules::Reorder do
  describe ".reorder_lcp" do
    it "reorders NP + LC to LC + NP" do
      # 桌子上 -> 上 桌子 (trên bàn)
      np = Zh2Vi::Node.leaf("NN", Zh2Vi::Token.new("桌子", "NN"), 0)
      lc = Zh2Vi::Node.leaf("LC", Zh2Vi::Token.new("上", "LC"), 1)
      lcp = Zh2Vi::Node.phrase("LCP", [np, lc])

      result = Zh2Vi::Rules::Reorder.reorder_lcp(lcp)

      result.children[0].token.try(&.text).should eq("上")
      result.children[1].token.try(&.text).should eq("桌子")
    end
  end

  describe ".reorder_np" do
    it "moves demonstrative to end" do
      # 这书 -> 书这 (sách này)
      dt = Zh2Vi::Node.leaf("DT", Zh2Vi::Token.new("这", "DT"), 0)
      nn = Zh2Vi::Node.leaf("NN", Zh2Vi::Token.new("书", "NN"), 1)
      np = Zh2Vi::Node.phrase("NP", [dt, nn])

      result = Zh2Vi::Rules::Reorder.reorder_np(np)

      result.children[0].token.try(&.text).should eq("书")
      result.children[1].token.try(&.text).should eq("这")
    end

    it "reorders adjective + noun" do
      # 漂亮书 -> 书 漂亮 (sách đẹp)
      jj = Zh2Vi::Node.leaf("JJ", Zh2Vi::Token.new("漂亮", "JJ"), 0)
      nn = Zh2Vi::Node.leaf("NN", Zh2Vi::Token.new("书", "NN"), 1)
      np = Zh2Vi::Node.phrase("NP", [jj, nn])

      result = Zh2Vi::Rules::Reorder.reorder_np(np)

      result.children[0].token.try(&.text).should eq("书")
      result.children[1].token.try(&.text).should eq("漂亮")
    end
  end

  describe ".process_vp" do
    it "moves aspect marker to front" do
      # 吃了 -> 了吃 (đã ăn)
      vv = Zh2Vi::Node.leaf("VV", Zh2Vi::Token.new("吃", "VV"), 0)
      as_node = Zh2Vi::Node.leaf("AS", Zh2Vi::Token.new("了", "AS"), 1)
      vp = Zh2Vi::Node.phrase("VP", [vv, as_node])

      result = Zh2Vi::Rules::Reorder.process_vp(vp)

      # AS should be before VV now
      result.children[0].token.try(&.text).should eq("了")
      result.children[0].vietnamese.should eq("đã")
      result.children[1].token.try(&.text).should eq("吃")
    end
  end

  describe ".process" do
    it "processes tree recursively" do
      # Build a simple tree and verify it gets processed
      vv = Zh2Vi::Node.leaf("VV", Zh2Vi::Token.new("吃", "VV"), 0)
      as_node = Zh2Vi::Node.leaf("AS", Zh2Vi::Token.new("了", "AS"), 1)
      vp = Zh2Vi::Node.phrase("VP", [vv, as_node])
      ip = Zh2Vi::Node.phrase("IP", [vp])

      result = Zh2Vi::Rules::Reorder.process(ip)

      # VP inside IP should be reordered
      vp_result = result.children[0]
      vp_result.children[0].token.try(&.text).should eq("了")
    end

    it "skips atomic nodes" do
      # NER entities should not be reordered
      nr1 = Zh2Vi::Node.leaf("NR", Zh2Vi::Token.new("北", "NR"), 0)
      nr2 = Zh2Vi::Node.leaf("NR", Zh2Vi::Token.new("京", "NR"), 1)
      np = Zh2Vi::Node.entity("NP-GPE", [nr1, nr2])

      result = Zh2Vi::Rules::Reorder.process(np)

      # Order should be preserved
      result.children[0].token.try(&.text).should eq("北")
      result.children[1].token.try(&.text).should eq("京")
    end
  end
end
