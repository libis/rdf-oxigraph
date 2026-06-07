module RDF
  module Oxigraph
    # In-process SHACL validation, backed by the rudof `shacl` engine in the native
    # extension. Decoupled from the store via serialized strings.
    module SHACL
      module_function

      # Validate a data graph against SHACL shapes. Both `data` and `shapes` are
      # strings of serialized RDF (default Turtle), or anything that responds to
      # #to_s. Returns a {Report}.
      def validate(data:, shapes:, data_format: :turtle, shapes_format: :turtle)
        raw = RDF::Oxigraph.shacl_validate(
          data.to_s, data_format.to_s, shapes.to_s, shapes_format.to_s
        )
        Report.new(raw)
      end

      # A SHACL validation report. `#results` is an array of hashes with string keys:
      # focus, path, value, source, severity, message.
      class Report
        attr_reader :raw

        def initialize(raw)
          @raw = raw
        end

        def conforms?
          @raw["conforms"]
        end

        def violations
          @raw["violations"]
        end

        def results
          @raw["results"]
        end

        # Human-readable validation report.
        def to_s
          @raw["text"]
        end
      end
    end
  end
end
