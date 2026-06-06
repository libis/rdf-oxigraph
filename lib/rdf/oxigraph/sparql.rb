module RDF
  module Oxigraph
    module SPARQL
      module_function

      # Convert a native Store#query tagged result into RDF.rb-native objects:
      #   ["boolean", bool]                  -> true / false
      #   ["solutions", vars, rows]          -> RDF::Query::Solutions
      #   ["graph", triples]                 -> RDF::Graph
      def results(tagged)
        case tagged[0]
        when "boolean"
          tagged[1]
        when "solutions"
          _, vars, rows = tagged
          solutions = RDF::Query::Solutions.new
          rows.each do |row|
            bindings = {}
            vars.each_with_index do |var, i|
              term = Conversion.deserialize(row[i])
              bindings[var.to_sym] = term unless term.nil?
            end
            solutions << RDF::Query::Solution.new(bindings)
          end
          solutions
        when "graph"
          graph = RDF::Graph.new
          tagged[1].each do |triple|
            graph << RDF::Statement.new(
              Conversion.deserialize(triple[0]),
              Conversion.deserialize(triple[1]),
              Conversion.deserialize(triple[2])
            )
          end
          graph
        else
          raise ArgumentError, "unknown query result kind: #{tagged[0].inspect}"
        end
      end

      # A small `SPARQL::Client`-shaped wrapper around a repository (anything that
      # responds to #sparql and #sparql_update). Covers the string-based query/update
      # surface; the chainable query-builder DSL of the sparql-client gem is out of scope.
      class Client
        attr_reader :repository

        def initialize(repository)
          @repository = repository
        end

        # Execute a SPARQL query string. `update: true` routes to #update (mirrors
        # the sparql-client gem's convention used by some callers).
        def query(query_string, **options)
          return update(query_string) if options[:update]
          @repository.sparql(query_string)
        end

        # Execute a SPARQL Update string.
        def update(update_string, **)
          @repository.sparql_update(update_string)
          self
        end
      end
    end
  end
end
