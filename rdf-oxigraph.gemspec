require_relative "lib/rdf/oxigraph/version"

Gem::Specification.new do |spec|
  spec.name        = "rdf-oxigraph"
  spec.version     = RDF::Oxigraph::VERSION
  spec.authors     = ["Mehmet Celik"]
  spec.email       = ["mehmet@celik.be"]
  spec.summary     = "Drop-in RDF.rb-compatible storage/SPARQL backed by oxigraph (Rust)"
  spec.description = "A Ruby RDF.rb backend (RDF::Repository + SPARQL::Client-compatible) " \
                     "backed by the oxigraph Rust engine via a magnus/rb-sys native extension."
  spec.homepage    = "https://github.com/libis/rdf-oxigraph"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.0.0"
  spec.required_rubygems_version = ">= 3.3.11"

  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir[
    "lib/**/*.rb",
    "ext/**/*.{rs,toml,rb,lock}",
    "Cargo.toml",
    "Cargo.lock",
    "*.gemspec",
    "README.md",
    "CHANGELOG.md",
    "LICENSE*"
  ]
  spec.require_paths = ["lib"]
  spec.extensions    = ["ext/rdf_oxigraph/extconf.rb"]

  spec.add_dependency "rdf", "~> 3.3"
  spec.add_dependency "rb_sys", "~> 0.9"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rake-compiler", "~> 1.2"
  spec.add_development_dependency "minitest", "~> 5.16"          # main test suite
  spec.add_development_dependency "rspec", "~> 3.0"              # rdf-spec conformance only
  spec.add_development_dependency "rdf-spec", "~> 3.3"           # rdf-spec conformance only
end
