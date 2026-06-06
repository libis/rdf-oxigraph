# rdf-oxigraph

A Ruby gem providing a drop-in **RDF.rb-compatible** storage + SPARQL backend powered by the
[oxigraph](https://github.com/oxigraph/oxigraph) Rust engine, via a
[magnus](https://github.com/matsadler/magnus) + [rb-sys](https://github.com/oxidize-rb/rb-sys)
native extension.

Goal: let existing RDF.rb / `SPARQL::Client` consumers (e.g. solis-core) run on a fast,
embedded, native SPARQL 1.1 engine without changing their code.

## Status

Early development. Phase 1 (native bridge proof-of-life) **works**: Ruby → Rust(magnus) →
oxigraph, loading Turtle and executing SPARQL (SELECT/ASK/CONSTRUCT, FILTER incl. REGEX,
PREFIX) end-to-end. See the full plan/roadmap in
`~/.claude/plans/lets-brainstorm-what-would-cheerful-corbato.md`.

Roadmap (backend chosen after an oxirs spike was ruled out — see plan):
1. ✅ Native bridge proof-of-life (`RDF::Oxigraph.probe`).
2. ✅ Term marshalling (RDF.rb terms ↔ oxigraph) + a `Store` class
   (`new`/`insert`/`delete`/`size`/`load`/`each_quad`/`query`).
3. ✅ `RDF::Repository` drop-in — **319/338 `rdf-spec` examples pass** (see Conformance).
4. `RDF::Reader`/`RDF::Writer` (Turtle/TriG/N-Triples/N-Quads).
5. `SPARQL::Client`-compatible facade (oxigraph supports PREFIX + full FILTER natively).
6. Packaging: precompiled cross-platform gems.
7. solis-core integration (`'oxigraph'` store type).

SHACL is not provided by oxigraph; solis keeps its external validator (optionally add `rudof` later).

## Conformance & known deviations

`RDF::Oxigraph::Repository` passes **319/338** of the `rdf-spec` `RDF::Repository`
shared examples (`bundle exec rspec`). The remaining ~19 failures stem from a single,
documented backend behavior:

- **oxigraph canonicalizes typed literals.** `"01"^^xsd:integer` is stored as
  `"1"^^xsd:integer`, and `"1.0e0"^^xsd:double` as its canonical form. rdf-spec treats
  distinct lexical forms as distinct terms, so the lexical-preservation / term-count /
  value-pattern tests fail. This is semantically reasonable (both denote the same value)
  and is harmless — generally beneficial — for the solis use case.
- `#dump` differs only in auto-assigned blank-node labels (triples are identical); full
  `#dump` support arrives with the readers/writers in step 4.

These are inherent to oxigraph's value-based storage and are not fixable in the gem.

## Build (development)

```bash
bundle install
# keep Rust build artifacts out of Dropbox:
CARGO_TARGET_DIR="$HOME/.cargo-target/rdf-oxigraph" bundle exec rake compile
ruby -Ilib -e 'require "rdf/oxigraph"; puts RDF::Oxigraph.probe("@prefix ex: <http://example.org/> . ex:a ex:b ex:c .", "ASK { ?s ?p ?o }")'
```

Requirements: Ruby >= 3.0 with headers, a Rust toolchain (rustup recommended), clang/libclang.

## License

MIT
