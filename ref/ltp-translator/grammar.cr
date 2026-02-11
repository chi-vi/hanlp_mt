require "./node"
require "./rules"
require "./rules/compare"
require "./rules/adj"
require "./rules/number"
require "./rules/adverb"
require "./rules/determiner"
require "./rules/complement"
require "./rules/punctuation"

module QTran
  class Grammar
    def initialize
    end

    def process(nodes : Array(MtNode)) : Array(MtNode)
      current_nodes = nodes

      # Recursively apply rules until stable (no size change)
      loop do
        prev_count = current_nodes.size

        # Phase 0.0: Punctuation / Chunking
        # Wrap quotes/parens to treat them as single units
        current_nodes = QTran::PunctuationRules.apply(current_nodes)

        # Phase 0: Adjective Rules (Measurement, Extent)
        # Run BEFORE VerbRules to prevent 'Dao+Le' being consumed as 'Da+Dao'.
        current_nodes = QTran::AdjRules.apply(current_nodes)

        # Phase 0.2: Number Rules
        current_nodes = QTran::NumberRules.apply(current_nodes)

        # Phase 0.5: Special Adverb Rules (Zui, Zheme...)
        current_nodes = QTran::AdverbRules.apply(current_nodes)

        # Phase 1: Noun Rules (includes Noun/Adj Phrasing and Relative Clauses)
        current_nodes = QTran::NounRules.apply(current_nodes)

        # Phase 2: Verb Rules (Time/Ba/Bei)
        current_nodes = QTran::VerbRules.apply(current_nodes)

        # Phase 2.5: Determiner Rules (Post-posing)
        current_nodes = QTran::DeterminerRules.apply(current_nodes)

        # Phase 2.8: Verb Complement Rules (Degree, Potential, Direction)
        current_nodes = QTran::ComplementRules.apply(current_nodes)

        # Phase 3: Preposition Rules
        current_nodes = QTran::PreposRules.apply(current_nodes)

        # Phase 4: Compare / Equative Rules (Bi, Xiang, Yiyang)
        current_nodes = QTran::CompareRules.apply(current_nodes)

        # Check stability
        break if current_nodes.size == prev_count
      end

      current_nodes
    end
  end
end
