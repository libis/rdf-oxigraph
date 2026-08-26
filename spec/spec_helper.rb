$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# rdf-spec fixtures are UTF-8; ensure Ruby doesn't default to US-ASCII when the
# locale is unset (otherwise RDF::Reader chokes with "invalid byte sequence").
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require "rdf/oxigraph"
require "rdf/spec"
require_relative "known_deviations"

RSpec.configure do |config|
  config.include RDF::Spec::Matchers

  # Mark the documented oxigraph deviations pending so the suite is green and a
  # genuine regression stands out. See spec/known_deviations.rb.
  matched = []

  config.before do |example|
    if KnownDeviations.match?(example.full_description)
      matched << KnownDeviations.normalize(example.full_description)
      pending KnownDeviations::REASON
    end
  end

  # If an entry stops matching (e.g. rdf-spec renamed the example), the example
  # itself will fail normally and turn CI red -- this just names the stale entry
  # so the cause is obvious. Only meaningful on a full run.
  config.after(:suite) do
    stale = KnownDeviations::EXAMPLES - matched
    unless stale.empty?
      warn "\nknown_deviations.rb: #{stale.size} entr#{stale.size == 1 ? "y" : "ies"} " \
           "matched no example (stale, or you ran a subset):"
      stale.each { |d| warn "  - #{d}" }
    end
  end
end
