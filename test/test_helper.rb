$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Keep UTF-8 regardless of locale (RDF data is UTF-8).
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require "json"
require "minitest/autorun"
require "rdf/oxigraph"
