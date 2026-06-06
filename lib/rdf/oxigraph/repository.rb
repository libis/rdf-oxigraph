module RDF
  module Oxigraph
    # An RDF.rb-compatible {RDF::Repository} backed by the native oxigraph store.
    #
    # Implements the storage backend protocol (insert/delete/each/count) over the
    # tagged-tuple bridge; the RDF::Enumerable/Queryable/Mutable mixins build the
    # rest of the RDF.rb surface on top.
    class Repository < RDF::Repository
      def initialize(**options, &block)
        @store = RDF::Oxigraph::Store.new
        super(**options, &block)
      end

      def supports?(feature)
        case feature.to_sym
        when :graph_name then true   # quad store
        when :literal_equality then true
        else false
        end
      end

      def durable?
        false # in-memory; persistent (RocksDB) variant comes later
      end

      def count
        @store.size
      end

      def empty?
        count.zero?
      end

      def each_statement(&block)
        return enum_for(:each_statement) unless block_given?
        @store.each_quad.each do |quad|
          block.call(Conversion.deserialize_statement(quad))
        end
      end
      alias_method :each, :each_statement

      def insert_statement(statement)
        raise ArgumentError, "incomplete statement: #{statement.inspect}" if statement.incomplete?
        s, p, o, g = Conversion.serialize_statement(statement)
        @store.insert(s, p, o, g)
      end

      def delete_statement(statement)
        s, p, o, g = Conversion.serialize_statement(statement)
        @store.delete(s, p, o, g)
      end
    end
  end
end
