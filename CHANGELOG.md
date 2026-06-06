# Changelog

## [Unreleased] (0.0.1)

Initial development release. A drop-in RDF.rb-compatible storage/SPARQL backend
powered by the [oxigraph](https://github.com/oxigraph/oxigraph) Rust engine via a
magnus + rb-sys native extension.

### Added
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
- Precompiled, platform-specific gems (install with no Rust toolchain required)
  for Linux x86_64/arm64 (glibc + musl) and macOS arm64/x86_64. oxigraph is built
  with `default-features = false` (in-memory store only, no RocksDB/C++), keeping
  the gem small (~2.5 MB) and Linux cross-compilation reliable.

### Not included
- SHACL validation. oxigraph has none, and the Rust alternative (rudof
  `shacl_validation`) is not currently buildable from crates.io. SHACL stays
  external for now (see README).
