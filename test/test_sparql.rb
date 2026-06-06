require_relative "test_helper"

# SPARQL query/update via oxigraph, returning RDF.rb-native result objects.
class TestSparql < Minitest::Test
  def setup
    @repo = RDF::Oxigraph::Repository.new
    @ex = RDF::Vocabulary.new("http://example.org/")
    @repo << RDF::Statement.new(@ex.alice, @ex.knows, @ex.bob)
    @repo << RDF::Statement.new(@ex.bob,   @ex.knows, @ex.carol)
    @repo << RDF::Statement.new(@ex.alice, @ex.age,   RDF::Literal.new(30))
  end

  def test_select_returns_solutions
    sols = @repo.sparql("SELECT ?s ?o WHERE { ?s <http://example.org/knows> ?o }")
    assert_kind_of RDF::Query::Solutions, sols
    assert_equal 2, sols.size
    solution = sols.first
    assert_kind_of RDF::Query::Solution, solution
    assert solution.bound?(:s)
    assert_kind_of RDF::URI, solution[:s]
  end

  def test_ask_returns_boolean
    assert_equal true,  @repo.sparql("ASK { ?s ?p ?o }")
    assert_equal false, @repo.sparql("ASK { <http://example.org/nobody> ?p ?o }")
  end

  def test_construct_returns_graph
    graph = @repo.sparql(
      "CONSTRUCT { ?s <http://example.org/knows> ?o } WHERE { ?s <http://example.org/knows> ?o }"
    )
    assert_kind_of RDF::Graph, graph
    assert_equal 2, graph.count
  end

  def test_prefix_and_filter
    sols = @repo.sparql(
      "PREFIX ex: <http://example.org/> SELECT ?s WHERE { ?s ex:age ?a FILTER(?a > 18) }"
    )
    assert_equal 1, sols.size
  end

  def test_solution_literal_value_type
    sols = @repo.sparql("SELECT ?a WHERE { ?s <http://example.org/age> ?a }")
    age = sols.first[:a]
    assert_kind_of RDF::Literal, age
    assert_equal 30, age.object
  end

  def test_update_insert_data
    @repo.sparql_update(
      "INSERT DATA { <http://example.org/x> <http://example.org/p> <http://example.org/y> }"
    )
    assert_equal 4, @repo.count
    assert @repo.sparql("ASK { <http://example.org/x> <http://example.org/p> <http://example.org/y> }")
  end

  def test_update_delete_where
    @repo.sparql_update("DELETE WHERE { ?s <http://example.org/knows> ?o }")
    assert_equal 1, @repo.count # only the age statement remains
  end

  def test_client_facade
    client = RDF::Oxigraph::SPARQL::Client.new(@repo)
    sols = client.query("SELECT ?s WHERE { ?s <http://example.org/knows> ?o }")
    assert_equal 2, sols.size

    client.query(
      "INSERT DATA { <http://example.org/m> <http://example.org/p> <http://example.org/n> }",
      update: true
    )
    assert_equal 4, @repo.count
  end
end
