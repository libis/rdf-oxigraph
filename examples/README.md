# Examples

Run from the gem root. During development pass `-Ilib` (so Ruby finds the compiled
extension); after `gem install rdf-oxigraph` you can drop it.

```bash
bundle exec rake compile            # once, builds the native extension
ruby -Ilib examples/01_drop_in_repository.rb
ruby -Ilib examples/02_load_and_serialize.rb
ruby -Ilib examples/03_sparql.rb
```

| File | Shows |
|------|-------|
| `01_drop_in_repository.rb` | The same RDF.rb code runs unchanged against the stock `RDF::Repository` and `RDF::Oxigraph::Repository`, with identical results — the drop-in claim. |
| `02_load_and_serialize.rb` | Loading Turtle and serializing to N-Triples / JSON-LD via standard RDF.rb interfaces (native oxigraph parse/serialize), plus format-registry resolution. |
| `03_sparql.rb` | SPARQL SELECT/ASK/CONSTRUCT + UPDATE via the native engine, returning RDF.rb-native result objects, incl. a `SPARQL::Client`-style wrapper. |
| `04_shacl.rb` | In-process SHACL validation (via the rudof `shacl` engine): validate a repository or two RDF strings, inspect conformance + violations. |

`data/books.ttl` is the shared sample dataset.
