require_relative "test_helper"

# In-process SHACL validation (native, via the rudof `shacl` engine).
class TestShacl < Minitest::Test
  SHAPES = <<~TTL.freeze
    @prefix sh:  <http://www.w3.org/ns/shacl#> .
    @prefix ex:  <http://example.org/> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
    ex:PersonShape a sh:NodeShape ;
      sh:targetClass ex:Person ;
      sh:property [ sh:path ex:name ; sh:minCount 1 ; sh:datatype xsd:string ] .
  TTL

  def test_conforming_data
    data = '@prefix ex: <http://example.org/> . ex:alice a ex:Person ; ex:name "Alice" .'
    report = RDF::Oxigraph::SHACL.validate(data: data, shapes: SHAPES)
    assert report.conforms?
    assert_equal 0, report.violations
    assert_empty report.results
  end

  def test_non_conforming_data
    data = "@prefix ex: <http://example.org/> . ex:bob a ex:Person ." # missing ex:name
    report = RDF::Oxigraph::SHACL.validate(data: data, shapes: SHAPES)
    refute report.conforms?
    assert_equal 1, report.violations
    assert_kind_of Array, report.results
    assert_includes report.to_s.downcase, "violation"
  end

  def test_repository_shacl_validate
    repo = RDF::Oxigraph::Repository.new
    ex = RDF::Vocabulary.new("http://example.org/")
    repo << RDF::Statement.new(ex.bob, RDF.type, ex.Person) # a Person, but no ex:name
    report = repo.shacl_validate(SHAPES)
    refute report.conforms?
    assert_equal 1, report.violations
  end
end
