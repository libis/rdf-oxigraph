require_relative "test_helper"

# Exercises RDF::Oxigraph::Repository as an RDF.rb-compatible repository.
class TestRepository < Minitest::Test
  def setup
    @repo = RDF::Oxigraph::Repository.new
    @ex = RDF::Vocabulary.new("http://example.org/")
  end

  def test_insert_count_and_each
    @repo << RDF::Statement.new(@ex.a, @ex.knows, @ex.b)
    @repo << RDF::Statement.new(@ex.a, @ex.name, RDF::Literal.new("Alice", language: :en))
    assert_equal 2, @repo.count
    refute @repo.empty?
    statements = @repo.each_statement.to_a
    assert_equal 2, statements.size
    assert(statements.all? { |s| s.is_a?(RDF::Statement) })
  end

  def test_has_statement
    st = RDF::Statement.new(@ex.a, @ex.knows, @ex.b)
    @repo << st
    assert @repo.has_statement?(st)
    refute @repo.has_statement?(RDF::Statement.new(@ex.a, @ex.knows, @ex.c))
  end

  def test_query_pattern
    @repo << RDF::Statement.new(@ex.a, @ex.knows, @ex.b)
    @repo << RDF::Statement.new(@ex.a, @ex.knows, @ex.c)
    objects = @repo.query([@ex.a, @ex.knows, nil]).map(&:object)
    assert_equal 2, objects.size
    assert_includes objects, @ex.b
    assert_includes objects, @ex.c
  end

  def test_delete
    st = RDF::Statement.new(@ex.a, @ex.knows, @ex.b)
    @repo << st
    @repo.delete(st)
    assert_equal 0, @repo.count
  end

  def test_typed_literal_round_trip
    @repo << RDF::Statement.new(@ex.a, @ex.age, RDF::Literal.new(30))
    object = @repo.query([@ex.a, @ex.age, nil]).first.object
    assert_kind_of RDF::Literal, object
    assert_equal RDF::URI("http://www.w3.org/2001/XMLSchema#integer"), object.datatype
    assert_equal 30, object.object
  end

  def test_language_literal_round_trip
    @repo << RDF::Statement.new(@ex.a, @ex.label, RDF::Literal.new("Alice", language: :en))
    object = @repo.query([@ex.a, @ex.label, nil]).first.object
    assert_equal :en, object.language
    assert_equal "Alice", object.value
  end

  def test_blank_node_round_trip
    @repo << RDF::Statement.new(RDF::Node.new("b1"), @ex.p, RDF::Node.new("b2"))
    st = @repo.each_statement.first
    assert_kind_of RDF::Node, st.subject
    assert_kind_of RDF::Node, st.object
  end

  def test_named_graph_distinct_from_default
    @repo << RDF::Statement.new(@ex.a, @ex.p, @ex.b, graph_name: @ex.g)
    @repo << RDF::Statement.new(@ex.a, @ex.p, @ex.b)
    assert_equal 2, @repo.count
  end

  def test_incomplete_statement_raises
    assert_raises(ArgumentError) do
      @repo.insert(RDF::Statement.new(@ex.a, nil, @ex.b))
    end
  end

  def test_supports_graph_name
    assert @repo.supports?(:graph_name)
  end
end
