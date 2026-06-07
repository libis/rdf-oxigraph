# SPARQL query + update via oxigraph's native engine, returning RDF.rb-native
# result objects (RDF::Query::Solutions / RDF::Graph / boolean).
#
#   ruby -Ilib examples/03_sparql.rb

require "rdf/oxigraph"

repo = RDF::Oxigraph::Repository.new
repo.load(File.expand_path("data/books.ttl", __dir__))

PREFIXES = "PREFIX ex: <http://example.org/> PREFIX dc: <http://purl.org/dc/terms/>"

puts "--- SELECT (with FILTER + ORDER BY) ---"
solutions = repo.sparql(<<~SPARQL)
  #{PREFIXES}
  SELECT ?title ?year WHERE {
    ?b a ex:Book ; dc:title ?title ; ex:year ?year .
    FILTER(?year >= 2014)
  } ORDER BY DESC(?year)
SPARQL
solutions.each { |s| puts "  #{s[:year]}  #{s[:title]}" } # => RDF::Query::Solution

puts "\n--- ASK ---"
puts "  any books? #{repo.sparql("#{PREFIXES} ASK { ?b a ex:Book }")}"

puts "\n--- CONSTRUCT (=> RDF::Graph) ---"
graph = repo.sparql("#{PREFIXES} CONSTRUCT { ?a ex:wrote ?b } WHERE { ?b ex:author ?a }")
puts "  #{graph.class}, #{graph.count} triples"

puts "\n--- UPDATE (INSERT DATA) ---"
repo.sparql_update("#{PREFIXES} INSERT DATA { ex:book4 a ex:Book ; dc:title \"New Book\" ; ex:year 2025 }")
puts "  count after insert: #{repo.count}"

puts "\n--- SPARQL::Client-style wrapper ---"
client = RDF::Oxigraph::SPARQL::Client.new(repo)
n = client.query("#{PREFIXES} SELECT (COUNT(?b) AS ?n) WHERE { ?b a ex:Book }").first[:n]
puts "  books now: #{n}"
