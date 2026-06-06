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

  def test_nquads_round_trip_preserves_graph
    quads = [
      [["uri", EX + "a"], ["uri", EX + "p"], ["uri", EX + "b"], ["uri", EX + "g"]]
    ]
    nq = RDF::Oxigraph.serialize(quads, "nquads")
    assert_includes nq, "<#{EX}g>"
    assert_equal quads, RDF::Oxigraph.parse(nq, "nquads")
  end
end
