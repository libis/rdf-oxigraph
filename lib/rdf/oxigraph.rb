require "rdf"
require_relative "oxigraph/version"

# Load the compiled native extension (built into lib/rdf/oxigraph/ by rake-compiler).
# Defines RDF::Oxigraph::Store.
require "rdf/oxigraph/rdf_oxigraph"

require_relative "oxigraph/conversion"
require_relative "oxigraph/format"
require_relative "oxigraph/sparql"
require_relative "oxigraph/shacl"
require_relative "oxigraph/repository"
