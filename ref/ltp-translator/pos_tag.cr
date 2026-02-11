module QTran
  enum PosTag
    None # Unknown or uninitialized

    # Nouns
    Noun    # n
    NDir    # nd (direction)
    NTime   # nt (time)
    NPlace  # nl (location)
    NPerson # nh (person)
    NSkill  # nz (specialized/skill?)
    NIdeo   # ni (idiom?)

    # Verbs
    Verb   # v
    VCo    # v + compl?
    VModal # opt / v_modal

    # Adjectives
    Adj     # a
    AdjStat # z (status adjective)

    # Pronouns
    Pronoun # r

    # Adverbs
    Adverb # d

    # Prepositions
    Prepos # p

    # Conjunctions
    Conj # c

    # Particles
    Part   # u
    PartDe # de (u)
    PartLe # le (u)

    # Numerals / Quantifiers
    Number # m
    Quant  # q

    # Comparisons
    Compar # Comparison marker (như, hơn)
    Rel    # Relation (bằng)

    # Punctuation
    Punct # wp

    # Special
    LitStr # For literals
    UrlStr # For URLs

    def self.from_ltp(tag : ::String) : PosTag
      case tag
      when "n"        then Noun
      when "nd"       then NDir
      when "nt"       then NTime
      when "nl", "ns" then NPlace
      when "nh"       then NPerson # Person name
      when "ni"       then NIdeo   # Organization/Institution
      when "nz"       then NSkill
      when "v"        then Verb
      when "a", "b"   then Adj
      when "z"        then AdjStat
      when "r"        then Pronoun
      when "d"        then Adverb
      when "p"        then Prepos
      when "c"        then Conj
      when "u"        then Part
      when "m"        then Number
      when "q"        then Quant
      when "wp"       then Punct
      else                 None
      end
    end

    def noun?
      self.in?(Noun, NDir, NTime, NPlace, NPerson, NSkill, NIdeo)
    end

    def n_place?
      self == NPlace
    end

    def n_dir?
      self == NDir
    end

    def n_person?
      self == NPerson || self == Pronoun
    end

    # Organization/Institution (ni)
    def n_org?
      self == NIdeo
    end

    # For 想 → nhớ pattern: person, place, or organization that can be "missed"
    def missable_object?
      self.n_person? || self.n_place? || self.n_org?
    end

    def verb?
      self.in?(Verb, VCo, VModal)
    end

    def adj?
      self.in?(Adj, AdjStat)
    end

    def pronoun?
      self == Pronoun
    end

    def adverb?
      self == Adverb
    end

    def prepos?
      self == Prepos
    end

    def conj?
      self == Conj
    end

    def part_de?
      self == PartDe || self == Part
    end
  end
end
