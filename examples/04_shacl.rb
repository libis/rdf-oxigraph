# In-process SHACL validation (native, via the rudof `shacl` engine).
#
#   ruby -Ilib examples/04_shacl.rb

require "rdf/oxigraph"

SHAPES = <<~TTL
  @prefix sh:  <http://www.w3.org/ns/shacl#> .
  @prefix ex:  <http://example.org/> .
  @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
  ex:PersonShape a sh:NodeShape ;
    sh:targetClass ex:Person ;
    sh:property [ sh:path ex:name ; sh:minCount 1 ; sh:datatype xsd:string ] .
TTL

ex = RDF::Vocabulary.new("http://example.org/")

# 1) Validate a repository's data against shapes.
repo = RDF::Oxigraph::Repository.new
repo << RDF::Statement.new(ex.alice, RDF.type, ex.Person)
repo << RDF::Statement.new(ex.alice, ex.name, RDF::Literal("Alice"))
repo << RDF::Statement.new(ex.bob, RDF.type, ex.Person) # missing ex:name

report = repo.shacl_validate(SHAPES)
puts "conforms? #{report.conforms?}   violations: #{report.violations}"
report.results.each do |r|
  puts "  - #{r['focus']}: #{r['severity']} (#{r['message']})"
end

puts "\n--- human-readable report ---"
puts report.to_s

# 2) Or validate two RDF strings directly (no repository needed).
puts "\n--- direct string validation ---"
ok = '@prefix ex: <http://example.org/> . ex:carol a ex:Person ; ex:name "Carol" .'
puts "valid person conforms? #{RDF::Oxigraph::SHACL.validate(data: ok, shapes: SHAPES).conforms?}"
