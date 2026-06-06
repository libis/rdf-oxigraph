require_relative "test_helper"

# Exercises the native RDF::Oxigraph::Store directly via the tagged-tuple wire format.
class TestStore < Minitest::Test
  EX = "http://example.org/".freeze
  INT = "http://www.w3.org/2001/XMLSchema#integer".freeze

  def setup
    @s = RDF::Oxigraph::Store.new
  end

  def uri(name)
    ["uri", EX + name]
  end

  def test_insert_is_idempotent_and_counts
    assert_equal true, @s.insert(uri("a"), uri("p"), uri("b"), nil)
    assert_equal 1, @s.size
    assert_equal false, @s.insert(uri("a"), uri("p"), uri("b"), nil) # already present
    assert_equal 1, @s.size
  end

  def test_term_round_trip_all_kinds
    @s.insert(uri("a"), uri("name"),  ["lit", "Alice", nil, nil], nil)        # simple literal
    @s.insert(uri("a"), uri("age"),   ["lit", "30", INT, nil], nil)           # typed literal
    @s.insert(uri("a"), uri("label"), ["lit", "Alice", nil, "en"], nil)       # language literal
    @s.insert(["bnode", "b1"], uri("p"), ["bnode", "b2"], nil)                # blank nodes

    quads = @s.each_quad
    assert_equal 4, quads.size

    by_pred = ->(p) { quads.find { |q| q[1] == ["uri", EX + p] } }

    assert_equal ["lit", "Alice", nil, "en"], by_pred.call("label")[2]
    assert_equal ["lit", "30", INT, nil],     by_pred.call("age")[2]

    bnode_quad = quads.find { |q| q[0][0] == "bnode" }
    assert_equal ["bnode", "b1"], bnode_quad[0]
    assert_equal ["bnode", "b2"], bnode_quad[2]
  end

  def test_named_graph_position
    @s.insert(uri("a"), uri("p"), uri("b"), uri("g"))
    assert_equal ["uri", EX + "g"], @s.each_quad.first[3]
  end

  def test_default_graph_is_nil
    @s.insert(uri("a"), uri("p"), uri("b"), nil)
    assert_nil @s.each_quad.first[3]
  end

  def test_delete
    @s.insert(uri("a"), uri("p"), uri("b"), nil)
    assert_equal true, @s.delete(uri("a"), uri("p"), uri("b"), nil)
    assert_equal 0, @s.size
  end

  def test_load_turtle
    @s.load("@prefix ex: <#{EX}> . ex:a ex:p ex:b, ex:c .", "turtle")
    assert_equal 2, @s.size
  end

  def test_query_ask
    @s.insert(uri("a"), uri("p"), uri("b"), nil)
    assert_equal ["boolean", true],  @s.query("ASK { ?s ?p ?o }")
    assert_equal ["boolean", false], @s.query("ASK { ?s <#{EX}none> ?o }")
  end

  def test_query_select_with_prefix
    @s.insert(uri("a"), uri("knows"), uri("b"), nil)
    @s.insert(uri("b"), uri("knows"), uri("c"), nil)
    kind, vars, rows = @s.query("PREFIX ex: <#{EX}> SELECT ?s ?o WHERE { ?s ex:knows ?o }")
    assert_equal "solutions", kind
    assert_equal %w[s o], vars
    assert_equal 2, rows.size
  end

  def test_query_filter_regex
    @s.insert(uri("a"), uri("name"), ["lit", "Alice", nil, nil], nil)
    @s.insert(uri("b"), uri("name"), ["lit", "Bob", nil, nil], nil)
    _, _, rows = @s.query("SELECT ?s WHERE { ?s <#{EX}name> ?n FILTER(REGEX(?n, '^Al')) }")
    assert_equal 1, rows.size
  end

  def test_query_construct
    @s.insert(uri("a"), uri("p"), uri("b"), nil)
    kind, triples = @s.query("CONSTRUCT { ?s ?p ?o } WHERE { ?s ?p ?o }")
    assert_equal "graph", kind
    assert_equal 1, triples.size
  end

  # Documents a known oxigraph deviation: typed numeric literals are canonicalized
  # on storage ("01"^^integer becomes "1"^^integer). See README "Conformance".
  def test_typed_literal_canonicalization_is_expected
    @s.insert(uri("a"), uri("p"), ["lit", "01", INT, nil], nil)
    assert_equal ["lit", "1", INT, nil], @s.each_quad.first[2]
  end
end
