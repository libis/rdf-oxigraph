$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# rdf-spec fixtures are UTF-8; ensure Ruby doesn't default to US-ASCII when the
# locale is unset (otherwise RDF::Reader chokes with "invalid byte sequence").
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require "rdf/oxigraph"
require "rdf/spec"

RSpec.configure do |config|
  config.include RDF::Spec::Matchers
end
