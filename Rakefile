require "rake/extensiontask"
require "rb_sys/extensiontask"

GEMSPEC = Gem::Specification.load("rdf-oxigraph.gemspec")

RbSys::ExtensionTask.new("rdf_oxigraph", GEMSPEC) do |ext|
  ext.lib_dir = "lib/rdf/oxigraph"
end

task default: :compile
