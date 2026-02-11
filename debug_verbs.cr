require "./spec/spec_helper"
require "./src/zh2vi/translator"
require "./src/zh2vi/data/raw_con"
require "yaml"

# Case: 我把苹果吃了
# Tree structure from spec/fixtures/grammar/verbs.yml:
# (TOP (IP (NP (PN 我)) (VP (BA 把) (IP (NP (NR 苹果)) (VP (VV 吃) (AS 了)))) (SP 了)))
# dep:
# 4:nsubj (我 -> 吃)
# 4:ba (把 -> 吃)
# 4:nsubj (苹果 -> 吃) - wait, this dep seems weird in fixture, usually object is dependent of BA or V
# 0:root (吃)
# 4:dep (了 -> 吃)

# Key part for DeprelRules.process_ba:
# VP children: [BA, IP]
# BA child has deprel "ba".
# IP child has children [NP, VP].
# We need to ensure DeprelRules sees the structure it expects.

puts "Building tree..."

# Leaf nodes
# 1. 我 (index 0)
wo_token = Zh2Vi::Token.new("我", "PN", nil, 4, "nsubj")
wo_node = Zh2Vi::Node.leaf("PN", wo_token, 0)
np_wo = Zh2Vi::Node.phrase("NP", [wo_node])

# 2. 把 (index 1)
ba_token = Zh2Vi::Token.new("把", "BA", nil, 4, "ba")
ba_node = Zh2Vi::Node.leaf("BA", ba_token, 1)

# 3. 苹果 (index 2)
# In fixture, dep head is 4 (吃). relation: nsubj (weird for object?).
apple_token = Zh2Vi::Token.new("苹果", "NR", nil, 4, "nsubj")
apple_node = Zh2Vi::Node.leaf("NR", apple_token, 2)
np_apple = Zh2Vi::Node.phrase("NP", [apple_node])

# 4. 吃 (index 3) - ROOT
eat_token = Zh2Vi::Token.new("吃", "VV", nil, 0, "root")
eat_node = Zh2Vi::Node.leaf("VV", eat_token, 3)

# 5. 了 (index 4)
le_token = Zh2Vi::Token.new("了", "AS", nil, 4, "asp") # fixture says asp?
le_node = Zh2Vi::Node.leaf("AS", le_token, 4)

vp_eat = Zh2Vi::Node.phrase("VP", [eat_node, le_node])

# IP (Object clause of BA)
ip_obj = Zh2Vi::Node.phrase("IP", [np_apple, vp_eat])

# VP (Main VP with BA)
vp_main = Zh2Vi::Node.phrase("VP", [ba_node, ip_obj])

# IP (Main sentence)
ip_main = Zh2Vi::Node.phrase("IP", [np_wo, vp_main])

# TOP
root = Zh2Vi::Node.phrase("TOP", [ip_main])

puts "Tree structure:"
root.to_bracket(STDOUT)
puts "\n"

puts "Running DeprelRules.process..."
Zh2Vi::Rules::DeprelRules.process(root)
puts "\nDone."

puts "Result tree:"
root.to_bracket(STDOUT)
puts "\n"
