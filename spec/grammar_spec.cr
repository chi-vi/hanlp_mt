require "./spec_helper"
require "yaml"
require "json"
require "../src/zh2vi/data/raw_con"

struct GrammarTestCase
  include YAML::Serializable

  getter tok : Array(String)
  getter pos : Array(String)

  # Recursive structure for CON
  getter con : Zh2Vi::RawCon

  # [[text, label, start, end]]
  getter ner : Array(Tuple(String, String, Int32, Int32))?

  # [[head, rel]]
  getter dep : Array(Tuple(Int32, String))?

  # [[tok, utt, val]]
  getter utt_dict : Array(Tuple(String, String, String))?

  # [[child, parent, drt, val, pval?]]
  # Using Array(YAML::Any) because length varies (4 or 5)
  getter drt_dict : Array(Array(YAML::Any))?

  getter expected : String
end

describe "Grammar Specs" do
  # Load all fixtures
  fixtures = Dir.glob(File.join("spec/fixtures/grammar", "*.yml")).sort

  fixtures.each do |file|
    filename = File.basename(file)

    describe filename do
      raw = File.read(file)
      test_cases = Array(GrammarTestCase).from_yaml(raw)

      test_cases.each_with_index do |tc, idx|
        # NER
        ner_spans = [] of Zh2Vi::NerSpan
        if ner_data = tc.ner
          ner_data.each do |n|
            # n is Tuple(String, String, Int32, Int32)
            # text, label, start, end
            ner_spans << Zh2Vi::NerSpan.new(n[2], n[3], n[1])
          end
        end

        # DEP
        dep_rels = [] of Zh2Vi::DepRel
        if dep_data = tc.dep
          dep_data.each_with_index do |d, i|
            # d is Tuple(Int32, String) => head, rel
            head = d[0]
            rel = d[1]
            dep_rels << Zh2Vi::DepRel.new(head, i + 1, rel)
          end
        end

        # Dictionaries
        pos_dict = Zh2Vi::Dict::PosDict.new
        if utt_data = tc.utt_dict
          utt_data.each do |e|
            # e is Tuple
            pos_dict.add(e[0], e[1], e[2])
          end
        end

        dep_dict = Zh2Vi::Dict::DepDict.new
        if drt_data = tc.drt_dict
          drt_data.each do |e|
            # e is Array(YAML::Any)
            child = e[0].as_s
            parent = e[1].as_s
            drt = e[2].as_s
            val = e[3].as_s
            pval = e.size > 4 ? e[4].as_s? : nil
            dep_dict.add(child, parent, drt, val, pval)
          end
        end

        # HanViet
        hanviet = Zh2Vi::Dict::HanViet.default

        translator = Zh2Vi::Translator.new(pos_dict, dep_dict, hanviet)

        it "translates case ##{idx + 1}: #{tc.tok.join}" do
          tree = translator.translate(
            tc.con, # Pass RawCon directly
            tc.tok,
            tc.pos,
            ner_spans,
            dep_rels
          )

          output = translator.output_text(tree)
          output.strip.should eq(tc.expected.strip)
        end
      end
    end
  end
end
