# Changelog

## [Unreleased] (0.0.1)

### Changed
- Upgraded oxigraph 0.5.8 → **0.5.13** and the rudof `shacl` / `rudof_rdf` crates
  0.3.3 → **0.3.39** (still a single shared oxigraph copy). rudof's
  `validate()` now takes a `ShaclConfig`; we pass the default (all results kept),
  so SHACL behaviour is unchanged.

### Fixed
- `require "rdf/oxigraph"` failed with a precompiled platform gem (e.g.
  `0.0.1-arm64-darwin`): those ship the native extension per Ruby version in
  `lib/rdf/oxigraph/<major.minor>/`, while the loader only looked in
  `lib/rdf/oxigraph/` (where a source build puts it). It now tries both.

Initial development release. A drop-in RDF.rb-compatible storage/SPARQL backend
powered by the [oxigraph](https://github.com/oxigraph/oxigraph) Rust engine via a
magnus + rb-sys native extension.

### Added
- Built on **oxigraph 0.5** (in-memory store; `default-features = false`, no RocksDB).
- Native `RDF::Oxigraph::Store` over `oxigraph::store::Store`
  (insert/delete/size/load/dump/each_quad/query/update) with full term
  marshalling (IRIs, blank nodes, simple/typed/language literals, default and
  named graphs).
- `RDF::Oxigraph::Repository < RDF::Repository` — passes 319/338 of the official
  `rdf-spec` `RDF::Repository` shared examples (the remainder is oxigraph's
  typed-literal canonicalization; see README).
- `RDF::Reader`/`RDF::Writer`/`RDF::Format` for Turtle, TriG, N-Triples, N-Quads,
  RDF/XML and JSON-LD (native oxigraph parse/serialize), plus fast
  `Repository#load`/`#dump`.
- SPARQL query + update: `Repository#sparql` (→ `RDF::Query::Solutions` /
  `RDF::Graph` / boolean), `Repository#sparql_update`, and a
  `RDF::Oxigraph::SPARQL::Client` string-based wrapper. Full FILTER/REGEX/PREFIX.
- In-process **SHACL validation** via the rudof `shacl` crate (0.3.x):
  `Repository#shacl_validate(shapes)` and `RDF::Oxigraph::SHACL.validate(data:, shapes:)`,
  returning a report with `#conforms?`, `#violations`, `#results`, `#to_s`. No external
  service; no RocksDB/C++ pulled in.
- Precompiled, platform-specific gems (install with no Rust toolchain required)
  for Linux x86_64/arm64 (glibc + musl) and macOS arm64/x86_64. oxigraph is built
  with `default-features = false` (in-memory store only, no RocksDB/C++), keeping
  Linux cross-compilation reliable.
