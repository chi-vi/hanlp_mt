require "yaml"
require "json"

struct Zh2Vi::RawInput
  include JSON::Serializable
  include YAML::Serializable

  @[JSON::Field(key: "tok/fine")]
  getter tok : Array(String)

  @[JSON::Field(key: "pos/ctb")]
  getter pos : Array(String)

  @[JSON::Field(key: "ner/ontonotes")]
  getter ner = [] of Tuple(String, String, Int32, Int32)

  @[JSON::Field(key: "con")]
  getter con = [] of RawCon

  @[JSON::Field(key: "dep")]
  getter dep = [] of Tuple(Int32, String)
end
