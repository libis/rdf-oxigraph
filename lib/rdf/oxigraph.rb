require "rdf"
require_relative "oxigraph/version"

# Load the compiled native extension. Defines RDF::Oxigraph::Store.
# - A precompiled platform gem (precompile.yml, e.g. 0.0.1-arm64-darwin) ships
#   one build per Ruby, in lib/rdf/oxigraph/<major.minor>/.
# - A source build (`rake compile`, or the source gem) puts it in lib/rdf/oxigraph/.
begin
  require "rdf/oxigraph/#{RUBY_VERSION[/\A\d+\.\d+/]}/rdf_oxigraph"
rescue LoadError
  require "rdf/oxigraph/rdf_oxigraph"
end

require_relative "oxigraph/conversion"
require_relative "oxigraph/format"
require_relative "oxigraph/sparql"
require_relative "oxigraph/shacl"
require_relative "oxigraph/repository"
