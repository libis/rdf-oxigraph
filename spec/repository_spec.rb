require_relative "spec_helper"
require "rdf/spec/repository"

describe RDF::Oxigraph::Repository do
  let(:repository) { RDF::Oxigraph::Repository.new }
  it_behaves_like "an RDF::Repository"
end
