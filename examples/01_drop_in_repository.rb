# Drop-in proof: the *same* RDF.rb code runs unchanged against the stock
# in-memory RDF::Repository and against RDF::Oxigraph::Repository, producing
# identical results.
#
#   ruby -Ilib examples/01_drop_in_repository.rb
#
# (After `gem install rdf-oxigraph` you can drop the `-Ilib`.)

require "rdf"
require "rdf/oxigraph"

EX = RDF::Vocabulary.new("http://example.org/")

# Plain RDF.rb — nothing oxigraph-specific in here. `repo` is any RDF::Repository.
def build(repo)
  repo << RDF::Statement.new(EX.alice, RDF.type, EX.Person)
  repo << RDF::Statement.new(EX.alice, EX.name, RDF::Literal("Alice"))
  repo << RDF::Statement.new(EX.alice, EX.knows, EX.bob)
  repo << RDF::Statement.new(EX.bob,   RDF.type, EX.Person)
  repo << RDF::Statement.new(EX.bob,   EX.name, RDF::Literal("Bob"))
  repo
end

def summarize(repo)
  {
    count:          repo.count,
    people:         repo.query([nil, RDF.type, EX.Person]).map { |s| s.subject.to_s }.sort,
    alice_knows:    repo.query([EX.alice, EX.knows, nil]).map { |s| s.object.to_s }.sort,
    has_alice_name: repo.has_statement?(RDF::Statement.new(EX.alice, EX.name, RDF::Literal("Alice"))),
    deleted_ok:     (repo.delete(RDF::Statement.new(EX.alice, EX.knows, EX.bob)); repo.count)
  }
end

stock = summarize(build(RDF::Repository.new))            # ships with rdf.rb
oxi   = summarize(build(RDF::Oxigraph::Repository.new))  # our native backend

puts "stock RDF::Repository      -> #{stock}"
puts "RDF::Oxigraph::Repository  -> #{oxi}"
puts
puts(stock == oxi ? "✅ identical results — drop-in confirmed" : "❌ results differ")
