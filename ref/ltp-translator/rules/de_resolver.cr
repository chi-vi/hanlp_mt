require "../node"
require "../pos_tag"
require "../word_classifier"

module QTran
  module DeResolver
    extend self

    # Resolve "de" value based on modifier type
    # Returns the string value for "de" ("" or "của")
    def resolve(modifier : MtNode, de_node : MtNode) : String
      # 1. Non-Possessive Modifiers -> ""

      # Adjectives, Verbs, Verb Phrases -> ""
      # "Beautiful girl", "Running man"
      if modifier.adj? || modifier.verb?
        return ""
      end

      # 2. Possessive Modifiers -> "của"

      # Pronouns -> "của"
      # "My book"
      if modifier.pronoun?
        return "của"
      end

      # Person Names (nh) or Person Nouns (suffix) -> "của"
      # "Xiao Ming's car", "Teacher's book"
      if WordClassifier.person?(modifier.key, modifier.tag)
        return "của"
      end

      # 2b. Check Phrase Head if modifier is a Phrase (Group)
      if modifier.key.empty? && !modifier.leaf?
        # Typically the head is the first child in swapped Noun logic?
        # NO. We swap: [Head] [Modifier].
        # But `modifier` HERE refers to the structural component BEFORE swap?
        # In `NounRules`: `modifier = n1` or `phrase`.
        # If `modifier` is a Phrase, it's `n1`.
        # `n1` is `[Head] [Mod]` (from previous swap).
        # "My Friend" -> `[Friend] [Me]`.
        # Is the "Person-ness" determined by the Head (Friend) or the Modifier (Me)?
        # "Friend of Me" is a Person.
        # "Car of Father" is a Car.
        # So we check the Semantic Type of the Phrase.
        # The Semantic Type is determined by the HEAD.
        # In our `NounRules`, we created parent: `parent.children << n2 (Head); parent.children << n1 (Mod)`.
        # So `children.first` is the Head.

        if (head = modifier.children.first?)
          # Recursive check? Or just check if Head is Person?
          # "Friend (Person)" -> Yes.
          # "Car (Object)" -> No.
          # But `resolve` needs `modifier` and `de`.
          # We just need to know if `modifier` (the Phrase) IS A PERSON.

          # Check Head properties
          if head.pronoun? || WordClassifier.person?(head.key, head.tag)
            return "của"
          end
        end
      end

      # 3. Noun Modifiers (Material, Abstract, Place, etc.) -> ""
      # "Wood table", "History value", "China capital"
      # Users generally prefer "Thu do Trung Quoc" over "Thu do Cua Trung Quoc"
      return ""
    end
  end
end
