require_relative "test_helper"
require "tempfile"

# Native (oxigraph-backed) RDF::Reader / RDF::Writer / RDF::Format and the
# Repository's fast load/dump paths.
class TestFormat < Minitest::Test
  EX = "http://example.org/".freeze
  TTL = "@prefix ex: <#{EX}> .\nex:a ex:p ex:b .\nex:a ex:n \"hi\"@en .\n".freeze

  def test_parse_module_function
    quads = RDF::Oxigraph.parse(TTL, "turtle")
    assert_equal 2, quads.size
  end

  def test_serialize_module_function
    quads = RDF::Oxigraph.parse(TTL, "turtle")
    nt = RDF::Oxigraph.serialize(quads, "ntriples")
    assert_includes nt, "<#{EX}a> <#{EX}p> <#{EX}b> ."
    assert_includes nt, '"hi"@en'
  end

  def test_reader_yields_statements
    statements = RDF::Oxigraph::TurtleReader.new(TTL).each_statement.to_a
    assert_equal 2, statements.size
    assert(statements.all? { |s| s.is_a?(RDF::Statement) })
  end

  def test_writer_buffers_and_serializes
    graph = RDF::Graph.new
    graph << RDF::Statement.new(RDF::URI(EX + "a"), RDF::URI(EX + "p"), RDF::URI(EX + "b"))
    out = RDF::Oxigraph::NTriplesWriter.buffer do |w|
      graph.each_statement { |s| w << s }
    end
    assert_includes out, "<#{EX}a> <#{EX}p> <#{EX}b> ."
  end

  def test_format_is_registered_by_content_type
    assert_equal RDF::Oxigraph::TurtleReader, RDF::Reader.for(content_type: "text/turtle")
    assert_includes RDF::Oxigraph::Turtle.content_type, "text/turtle"
  end

  def test_repository_native_load_and_dump
    repo = RDF::Oxigraph::Repository.new
    Tempfile.create(["data", ".ttl"]) do |f|
      f.write(TTL)
      f.flush
      repo.load(f.path)
    end
    assert_equal 2, repo.count

    dump = repo.dump(:ntriples)
    assert_includes dump, "<#{EX}a> <#{EX}p> <#{EX}b> ."
    assert_includes dump, '"hi"@en'
  end

  def test_jsonld_serialize_and_parse_round_trip
    quads = RDF::Oxigraph.parse(TTL, "turtle") # 2 triples
    jsonld = RDF::Oxigraph.serialize(quads, "jsonld")
    puts ::JSON.pretty_generate(JSON.parse(jsonld))
    assert_includes jsonld, "#{EX}p"
    assert_equal 2, RDF::Oxigraph.parse(jsonld, "jsonld").size
  end

  def test_jsonld_writer_and_dump
    repo = RDF::Oxigraph::Repository.new
    repo << RDF::Statement.new(RDF::URI(EX + "a"), RDF::URI(EX + "p"), RDF::URI(EX + "b"))
    assert_includes repo.dump(:jsonld), "#{EX}b"

    graph = RDF::Graph.new
    graph << RDF::Statement.new(RDF::URI(EX + "a"), RDF::URI(EX + "n"), RDF::Literal.new("hi"))
    out = RDF::Oxigraph::JsonLdWriter.buffer { |w| graph.each_statement { |s| w << s } }
    assert_includes out, "hi"
  end

  def test_jsonld_format_registered
    assert_includes RDF::Oxigraph::JsonLd.content_type, "application/ld+json"
    assert_equal RDF::Oxigraph::JsonLdReader, RDF::Reader.for(content_type: "application/ld+json")
  end

  def test_nquads_round_trip_preserves_graph
    quads = [
      [["uri", EX + "a"], ["uri", EX + "p"], ["uri", EX + "b"], ["uri", EX + "g"]]
    ]
    nq = RDF::Oxigraph.serialize(quads, "nquads")
    assert_includes nq, "<#{EX}g>"
    assert_equal quads, RDF::Oxigraph.parse(nq, "nquads")
  end
end
