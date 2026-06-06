require "rake/testtask"
require "rake/extensiontask"
require "rb_sys/extensiontask"

GEMSPEC = Gem::Specification.load("rdf-oxigraph.gemspec")

RbSys::ExtensionTask.new("rdf_oxigraph", GEMSPEC) do |ext|
  ext.lib_dir = "lib/rdf/oxigraph"
end

# Main suite: Minitest (matches solis-core).
Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList["test/test_*.rb"]
  t.warning = false
end
task test: :compile

# Conformance suite: rdf-spec shared examples (RSpec). Reports the rdf-spec
# baseline; ~19 expected failures are oxigraph typed-literal canonicalization
# (see README "Conformance & known deviations").
begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:conformance) do |t|
    t.pattern = "spec/**/*_spec.rb"
  end
  task conformance: :compile
rescue LoadError
  desc "rdf-spec conformance (requires rspec + rdf-spec)"
  task :conformance do
    abort "rspec/rdf-spec not installed; run `bundle install`"
  end
end

task default: :test
