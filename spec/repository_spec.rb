require_relative "spec_helper"
require "rdf/spec/repository"

# rdf-spec conformance for RDF::Oxigraph::Repository.
#
# ~19 examples are expected to fail: oxigraph canonicalizes typed literals
# ("01"^^xsd:integer is stored as "1"^^xsd:integer), and rdf-spec treats distinct
# lexical forms as distinct terms. See README "Conformance & known deviations".
describe RDF::Oxigraph::Repository do
  let(:repository) { RDF::Oxigraph::Repository.new }
  it_behaves_like "an RDF::Repository"
end
