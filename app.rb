require 'json'
require 'net/http'
require "pry"


# DBpedia にクエリを投げ結果を json で取得
# http://ja.dbpedia.org/sparql
#
# select distinct ?anime_name ?actor_name where {
# ?anime <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://dbpedia.org/ontology/Anime> ;
#     <http://xmlns.com/foaf/0.1/name> ?anime_name ;
#     <http://ja.dbpedia.org/property/出演者> ?actor .
# ?actor <http://www.w3.org/2000/01/rdf-schema#label> ?actor_name .
# }

request_url = "http://ja.dbpedia.org/sparql?default-graph-uri=http%3A%2F%2Fja.dbpedia.org&query=select+distinct+%3Fanime_name+%3Factor_name+where+%7B%0D%0A+%3Fanime+%3Chttp%3A%2F%2Fwww.w3.org%2F1999%2F02%2F22-rdf-syntax-ns%23type%3E+%3Chttp%3A%2F%2Fdbpedia.org%2Fontology%2FAnime%3E+%3B%0D%0A++++++%3Chttp%3A%2F%2Fxmlns.com%2Ffoaf%2F0.1%2Fname%3E+%3Fanime_name+%3B%0D%0A+++++%3Chttp%3A%2F%2Fja.dbpedia.org%2Fproperty%2F%E5%87%BA%E6%BC%94%E8%80%85%3E+%3Factor+.%0D%0A%3Factor+%3Chttp%3A%2F%2Fwww.w3.org%2F2000%2F01%2Frdf-schema%23label%3E+%3Factor_name+.%0D%0A%7D&format=application%2Fsparql-results%2Bjson&timeout=0&debug=on"

uri = URI.parse(request_url)
json = Net::HTTP.get(uri)
result = JSON.parse(json)

# 結果の json をパースして辞書を作成
relation_dict = result["results"]["bindings"].map do |line|
  {
    anime: line["anime_name"]["value"].gsub("\'", "\\'").gsub('"', '\\"'),
    actor: line["actor_name"]["value"]
  }
end

anime_dic = relation_dict.map {|line| line[:anime]}.uniq!
actor_dic = relation_dict.map {|line| line[:actor]}.uniq!

# neoj4のクエリを作成
query = 'CREATE '

animation_create_format = '(anime%d:Anime {name: "%s"}), '

anime_dic.each.with_index do |name, index|
  query += sprintf(animation_create_format, index, name)
end

actor_create_format = '(actor%d:Actor {name: "%s"}), '

actor_dic.each.with_index do |name, index|
  query += sprintf(actor_create_format, index, name)
end

relation_create_format = '(actor%d)-[:ACTS]->(anime%d), '

relation_dict.each do |relation|
  anime_index = anime_dic.index(relation[:anime])
  actor_index = actor_dic.index(relation[:actor])
  query += sprintf(relation_create_format, actor_index, anime_index)
end


query = query[0..-3]
query += ";"

puts query

# 取得したクエリを neo4j に登録。
