module RDF
  module Oxigraph
    # Native-format strings keyed by RDF.rb format symbol.
    FORMATS = {
      turtle:   "turtle",
      ntriples: "ntriples",
      nquads:   "nquads",
      trig:     "trig",
      rdfxml:   "rdfxml",
      jsonld:   "jsonld"
    }.freeze

    # Map an RDF.rb format symbol (or content type / file name) to the native
    # oxigraph format string, or nil if unsupported.
    def self.native_format(format)
      return FORMATS[format] if format.is_a?(Symbol)

      fmt = RDF::Format.for(format)
      fmt && FORMATS[fmt.to_sym]
    end

    # Batch RDF::Reader backed by oxigraph's native parsers. Subclasses set the
    # oxigraph format via `oxigraph_format`.
    class Reader < RDF::Reader
      def self.oxigraph_format(value = nil)
        @oxigraph_format = value unless value.nil?
        @oxigraph_format
      end

      def initialize(input = $stdin, **options, &block)
        @content = input.respond_to?(:read) ? input.read : input.to_s
        super
      end

      def each_statement
        return enum_for(:each_statement) unless block_given?
        RDF::Oxigraph.parse(@content, self.class.oxigraph_format).each do |quad|
          yield Conversion.deserialize_statement(quad)
        end
      end
      alias_method :each, :each_statement

      def each_triple
        return enum_for(:each_triple) unless block_given?
        each_statement { |st| yield(st.subject, st.predicate, st.object) }
      end
    end

    # Batch RDF::Writer backed by oxigraph's native serializers. Buffers statements
    # and serializes once on epilogue. Subclasses set `oxigraph_format`.
    class Writer < RDF::Writer
      def self.oxigraph_format(value = nil)
        @oxigraph_format = value unless value.nil?
        @oxigraph_format
      end

      def initialize(output = $stdout, **options, &block)
        @quads = []
        super
      end

      def write_statement(statement)
        @quads << Conversion.serialize_statement(statement)
        statement
      end

      def write_triple(subject, predicate, object)
        write_statement(RDF::Statement.new(subject, predicate, object))
      end

      def write_epilogue
        @output.write(RDF::Oxigraph.serialize(@quads, self.class.oxigraph_format))
        super
      end
    end

    class TurtleReader < Reader; oxigraph_format "turtle"; end
    class TurtleWriter < Writer; oxigraph_format "turtle"; end
    class Turtle < RDF::Format
      content_type "text/turtle", extension: :ttl
      reader { TurtleReader }
      writer { TurtleWriter }
    end

    class NTriplesReader < Reader; oxigraph_format "ntriples"; end
    class NTriplesWriter < Writer; oxigraph_format "ntriples"; end
    class NTriples < RDF::Format
      content_type "application/n-triples", extension: :nt
      reader { NTriplesReader }
      writer { NTriplesWriter }
    end

    class NQuadsReader < Reader; oxigraph_format "nquads"; end
    class NQuadsWriter < Writer; oxigraph_format "nquads"; end
    class NQuads < RDF::Format
      content_type "application/n-quads", extension: :nq
      reader { NQuadsReader }
      writer { NQuadsWriter }
    end

    class TriGReader < Reader; oxigraph_format "trig"; end
    class TriGWriter < Writer; oxigraph_format "trig"; end
    class TriG < RDF::Format
      content_type "application/trig", extension: :trig
      reader { TriGReader }
      writer { TriGWriter }
    end

    class JsonLdReader < Reader; oxigraph_format "jsonld"; end
    class JsonLdWriter < Writer; oxigraph_format "jsonld"; end
    class JsonLd < RDF::Format
      content_type "application/ld+json", extension: :jsonld
      reader { JsonLdReader }
      writer { JsonLdWriter }
    end
  end
end
