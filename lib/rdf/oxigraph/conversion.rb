module RDF
  module Oxigraph
    # Maps between RDF.rb terms and the native extension's tagged-tuple wire format.
    #
    #   IRI:        ["uri",   "<iri>"]
    #   blank node: ["bnode", "<id>"]
    #   literal:    ["lit",   "<value>", <datatype-iri or nil>, <lang or nil>]
    #   nil (e.g. default graph): nil
    module Conversion
      module_function

      # RDF.rb term -> tagged tuple (or nil).
      def serialize(term)
        case term
        when nil
          nil
        when RDF::URI
          ["uri", term.to_s]
        when RDF::Node
          ["bnode", term.id.to_s]
        when RDF::Literal
          if term.language? && !term.language.to_s.empty?
            ["lit", term.value, nil, term.language.to_s]
          else
            ["lit", term.value, term.datatype.to_s, nil]
          end
        else
          raise ArgumentError, "cannot serialize term: #{term.inspect}"
        end
      end

      # tagged tuple (or nil) -> RDF.rb term.
      def deserialize(tuple)
        return nil if tuple.nil?

        case tuple[0]
        when "uri"
          RDF::URI.new(tuple[1])
        when "bnode"
          RDF::Node.new(tuple[1])
        when "lit"
          value, datatype, lang = tuple[1], tuple[2], tuple[3]
          if lang && !lang.empty?
            RDF::Literal.new(value, language: lang.to_sym)
          elsif datatype && !datatype.empty?
            RDF::Literal.new(value, datatype: RDF::URI.new(datatype))
          else
            RDF::Literal.new(value)
          end
        else
          raise ArgumentError, "cannot deserialize tuple: #{tuple.inspect}"
        end
      end

      # RDF::Statement -> [s, p, o, g] tagged tuples.
      def serialize_statement(statement)
        [
          serialize(statement.subject),
          serialize(statement.predicate),
          serialize(statement.object),
          statement.graph_name ? serialize(statement.graph_name) : nil
        ]
      end

      # [s, p, o, g] tagged tuples -> RDF::Statement.
      def deserialize_statement(quad)
        RDF::Statement.new(
          deserialize(quad[0]),
          deserialize(quad[1]),
          deserialize(quad[2]),
          graph_name: deserialize(quad[3])
        )
      end
    end
  end
end
