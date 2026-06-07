# Loading and serializing through the standard RDF.rb interfaces — backed by
# oxigraph's native parsers/serializers (Turtle, N-Triples, JSON-LD, ...).
#
#   ruby -Ilib examples/02_load_and_serialize.rb

require "rdf/oxigraph"

DATA = File.expand_path("data/books.ttl", __dir__)

repo = RDF::Oxigraph::Repository.new
repo.load(DATA) # native Turtle parse, straight into the store
puts "loaded #{repo.count} triples from #{File.basename(DATA)}"

# Standard RDF.rb enumeration / pattern query — same API as any RDF::Repository.
dc_title = RDF::URI("http://purl.org/dc/terms/title")
titles = repo.query([nil, dc_title, nil]).map { |s| s.object.to_s }.sort
puts "titles: #{titles.join(', ')}"

# Serialize to other formats natively (RDF::Enumerable#dump).
puts "\n--- N-Triples (first 2 lines) ---"
puts repo.dump(:ntriples).lines.first(2).join

puts "--- JSON-LD ---"
puts repo.dump(:jsonld)

# It also plugs into RDF.rb's format registry: RDF::Reader/Writer.for(...) resolves
# to the oxigraph-backed reader/writer by content type or file extension.
reader = RDF::Reader.for(content_type: "text/turtle")
writer = RDF::Writer.for(:ntriples)
puts "\nRDF::Reader.for('text/turtle') => #{reader}"
puts "RDF::Writer.for(:ntriples)     => #{writer}"
