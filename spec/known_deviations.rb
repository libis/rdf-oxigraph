# Known, documented deviations from the rdf-spec `RDF::Repository` contract.
#
# These examples are marked *pending* rather than allowed to fail, so a normal
# `rake conformance` run is green and CI stays meaningful. RSpec's pending
# semantics give us the safety net for free:
#
#   * a listed example that still fails  -> reported as pending, build stays green
#   * a listed example that starts PASSING -> reported as a FAILURE ("expected
#     pending ... to fail"), so a deviation that gets fixed upstream can't sit
#     here unnoticed -- delete the entry when that happens
#   * an entry that no longer matches any example (upstream renamed it) -> that
#     example is no longer marked pending, so it fails normally and the build
#     goes red. Stale entries announce themselves; `spec_helper.rb` also prints
#     a warning listing anything that went unmatched.
#
# Every entry below has the same root cause -- see "Conformance & known
# deviations" in the README.
module KnownDeviations
  REASON = "known oxigraph deviation: value-based storage canonicalizes " \
           "typed literals (see README, 'Conformance & known deviations')"

  # Stripped from the front of each description below, purely to keep the
  # entries readable.
  PREFIX = "RDF::Oxigraph::Repository behaves like an RDF::Repository "

  # Some rdf-spec descriptions embed a statement's `inspect` output, which
  # contains a per-process object id (`#<RDF::Statement:0x6d8 ...>`). Those ids
  # shift between runs, so normalize them away before matching.
  # Note also that a few rdf-spec examples are bare `specify do ... end` blocks
  # with no docstring. RSpec generates their description from the last matcher
  # used, which only happens *after* the example runs -- so in a `before` hook
  # the description is just the enclosing group (e.g. "... #has_term? ").
  # Those entries are listed in that shorter pre-execution form.
  def self.normalize(full_description)
    full_description.gsub(/0x[0-9a-f]+/, "0xX").sub(PREFIX, "").strip
  end

  def self.match?(full_description)
    EXAMPLES.include?(normalize(full_description))
  end

  EXAMPLES = [
    # -- #dump differs only in auto-assigned blank node labels ----------------
    "as dataset behaves like an RDF::Dataset when enumerating statements behaves like an RDF::Enumerable when dumping should implement #dump",

    # -- lexical form not preserved: "01"^^xsd:integer is stored as "1" ------
    "as dataset behaves like an RDF::Dataset when enumerating statements behaves like an RDF::Enumerable when enumerating statements #has_statement? should have all statements",
    "as dataset behaves like an RDF::Dataset when enumerating statements behaves like an RDF::Enumerable when enumerating terms #has_term?",
    "as dataset behaves like an RDF::Dataset when enumerating statements behaves like an RDF::Enumerable when enumerating terms #each_term has correct number of terms",
    "as dataset behaves like an RDF::Dataset when enumerating statements behaves like an RDF::Enumerable when enumerating graphs #project_graph default graph should return default triples",
    "as dataset behaves like an RDF::Dataset when enumerating statements behaves like an RDF::Enumerable when converting #to_h should have as many keys as subjects",
    "when updating behaves like an RDF::Mutable RDF::Mutable writability behaves like an RDF::Writable when inserting statements should support inserting multiple statements at a time",
    "when updating behaves like an RDF::Mutable RDF::Mutable writability behaves like an RDF::Writable when inserting statements inserts literal with unique lexical value",
    "when updating behaves like an RDF::Mutable RDF::Mutable when deleting statements does not delete literal with different lexical value",

    # -- value-based matching: distinct lexical forms match one stored term ---
    "as dataset behaves like an RDF::Dataset when querying statements behaves like an RDF::Queryable RDF::Queryable#query when called with specific patterns returns [#<RDF::Statement:0xX(<http://example.org/xi1> <http://example.org/p> \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> .)>, #<RDF::Statement:0xX(<http://example.org/xi2> <http://example.org/p> \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> .)>] given [nil, RDF::URI(<http://example.org/p>), 1]",
    "as dataset behaves like an RDF::Dataset when querying statements behaves like an RDF::Queryable RDF::Queryable#query when called with specific patterns returns [#<RDF::Statement:0xX(<http://example.org/xi1> <http://example.org/p> \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> .)>, #<RDF::Statement:0xX(<http://example.org/xi2> <http://example.org/p> \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> .)>] given [nil, nil, 1]",
    "as dataset behaves like an RDF::Dataset when querying statements behaves like an RDF::Queryable RDF::Queryable#query when called with specific patterns returns [#<RDF::Statement:0xX(<http://example.org/xd1> <http://example.org/p> \"1.0e0\"^^<http://www.w3.org/2001/XMLSchema#double> .)>] given [nil, RDF::URI(<http://example.org/p>), \"1.0e0\" R:L:(Double)]",
    "as dataset behaves like an RDF::Dataset when querying statements behaves like an RDF::Queryable RDF::Queryable#query when called with specific patterns from SPARQL data/r2/expr-equals graph-1 has two solutions",
    "as dataset behaves like an RDF::Dataset when querying statements behaves like an RDF::Queryable RDF::Queryable#query when called with specific patterns from SPARQL data/r2/expr-equals graph-2 has one solution",
    "as dataset behaves like an RDF::Dataset when querying statements behaves like an RDF::Queryable RDF::Queryable#query when called with specific patterns from SPARQL data/r2/expr-equals graph-2 has xd1 as a solution",
    "as dataset behaves like an RDF::Dataset when querying statements behaves like an RDF::Queryable RDF::Queryable#query_pattern with specific patterns returns [#<RDF::Statement:0xX(<http://example.org/xi1> <http://example.org/p> \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> .)>, #<RDF::Statement:0xX(<http://example.org/xi2> <http://example.org/p> \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> .)>] given [nil, RDF::URI(<http://example.org/p>), 1]",
    "as dataset behaves like an RDF::Dataset when querying statements behaves like an RDF::Queryable RDF::Queryable#query_pattern with specific patterns returns [#<RDF::Statement:0xX(<http://example.org/xi1> <http://example.org/p> \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> .)>, #<RDF::Statement:0xX(<http://example.org/xi2> <http://example.org/p> \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> .)>] given [nil, nil, 1]",
    "as dataset behaves like an RDF::Dataset when querying statements behaves like an RDF::Queryable RDF::Queryable#query_pattern with specific patterns returns [#<RDF::Statement:0xX(<http://example.org/xd1> <http://example.org/p> \"1.0e0\"^^<http://www.w3.org/2001/XMLSchema#double> .)>] given [nil, RDF::URI(<http://example.org/p>), \"1.0e0\" R:L:(Double)]",
    "as dataset behaves like an RDF::Dataset when querying statements behaves like an RDF::Queryable RDF::Queryable#first_value returns an appropriate value when the pattern matches"
  ].freeze
end
