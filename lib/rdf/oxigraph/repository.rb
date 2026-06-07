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

      # Fast bulk load via oxigraph's native parser (skips per-statement Ruby
      # inserts). Falls back to RDF::Mutable#load for unsupported formats or when
      # a graph_name override is requested.
      def load(filename, **options)
        format = options[:format] || RDF::Format.for(file_name: filename.to_s)&.to_sym
        native = RDF::Oxigraph::FORMATS[format]
        return super if native.nil? || options[:graph_name]
        @store.load(File.read(filename), native)
        self
      end

      # Fast native serialization of the whole repository for supported formats;
      # falls back to RDF::Enumerable#dump otherwise.
      def dump(format, **options)
        native = format.is_a?(Symbol) && RDF::Oxigraph::FORMATS[format]
        return super if native == false || native.nil?
        @store.dump(native)
      end

      # Execute a SPARQL query string via oxigraph's native engine. Returns
      # RDF.rb-native results: RDF::Query::Solutions (SELECT), RDF::Graph
      # (CONSTRUCT/DESCRIBE), or true/false (ASK).
      def sparql(query_string)
        RDF::Oxigraph::SPARQL.results(@store.query(query_string))
      end

      # Execute a SPARQL 1.1 Update string against this repository.
      def sparql_update(update_string)
        @store.update(update_string)
        self
      end

      # Validate this repository's data against SHACL `shapes` (a serialized-RDF
      # string). Returns an RDF::Oxigraph::SHACL::Report.
      def shacl_validate(shapes, shapes_format: :turtle)
        RDF::Oxigraph::SHACL.validate(
          data: @store.dump("ntriples"),
          data_format: :ntriples,
          shapes: shapes,
          shapes_format: shapes_format
        )
      end
    end
  end
end
