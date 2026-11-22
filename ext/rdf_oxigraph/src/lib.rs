//! Native bridge: Ruby <-> oxigraph (magnus + rb-sys).
//!
//! Exposes `RDF::Oxigraph::Store`, a thin wrapper over `oxigraph::store::Store`.
//!
//! Terms cross the boundary in an RDF.rb-agnostic **tagged-tuple** wire format
//! (Ruby Arrays), so the Rust side never depends on RDF.rb. The Ruby layer maps
//! these to/from `RDF::URI` / `RDF::Literal` / `RDF::Node`:
//!   - IRI:        `["uri",   "<iri>"]`
//!   - blank node: `["bnode", "<id>"]`
//!   - literal:    `["lit",   "<value>", <datatype-iri or nil>, <lang or nil>]`
//!   - default graph / nil graph: Ruby `nil`
//!
//! `query` always returns a tagged result Array:
//!   - ASK:                `["boolean", true|false]`
//!   - SELECT:             `["solutions", ["v1","v2",...], [[term|nil, ...], ...]]`
//!   - CONSTRUCT/DESCRIBE: `["graph", [[s,p,o], ...]]`

use magnus::{
    function, method, prelude::*, value::ReprValue, Error, RArray, RHash, Ruby, TryConvert, Value,
};
use oxigraph::io::{JsonLdProfileSet, RdfFormat, RdfParser, RdfSerializer};
use oxigraph::model::{BlankNode, GraphName, Literal, NamedNode, NamedOrBlankNode, Quad, Term};
use oxigraph::sparql::{QueryResults, SparqlEvaluator};
use oxigraph::store::Store as OxiStore;

// In-process SHACL via the rudof `shacl` crate. It uses its own RDF stack
// (rudof_rdf, also on oxigraph 0.5); we only pass serialized strings across.
use rudof_rdf::rdf_core::RDFFormat as RudofFormat;
use rudof_rdf::rdf_impl::{OxigraphInMemory, ReaderMode};
use shacl::validator::processor::{GraphValidation, ShaclProcessor};
use shacl::validator::store::{Graph as ShaclGraph, ShaclDataManager};
use shacl::validator::{ShaclConfig, ShaclValidationMode};
use std::io::Cursor;

fn err<E: std::fmt::Display>(e: E) -> Error {
    Error::new(magnus::exception::runtime_error(), e.to_string())
}

// ---------- Ruby (tagged tuple) -> oxigraph ----------

fn ruby_to_named(val: Value) -> Result<NamedNode, Error> {
    let arr = RArray::try_convert(val)?;
    let tag: String = arr.entry(0)?;
    if tag != "uri" {
        return Err(err(format!("expected IRI term, got tag {tag:?}")));
    }
    let iri: String = arr.entry(1)?;
    NamedNode::new(iri).map_err(err)
}

fn ruby_to_term(val: Value) -> Result<Term, Error> {
    let arr = RArray::try_convert(val)?;
    let tag: String = arr.entry(0)?;
    match tag.as_str() {
        "uri" => {
            let iri: String = arr.entry(1)?;
            Ok(NamedNode::new(iri).map_err(err)?.into())
        }
        "bnode" => {
            let id: String = arr.entry(1)?;
            Ok(BlankNode::new(id).map_err(err)?.into())
        }
        "lit" => {
            let value: String = arr.entry(1)?;
            let datatype: Option<String> = arr.entry(2)?;
            let lang: Option<String> = arr.entry(3)?;
            let lit = match (lang, datatype) {
                (Some(l), _) => Literal::new_language_tagged_literal(value, l).map_err(err)?,
                (None, Some(dt)) => {
                    Literal::new_typed_literal(value, NamedNode::new(dt).map_err(err)?)
                }
                (None, None) => Literal::new_simple_literal(value),
            };
            Ok(lit.into())
        }
        other => Err(err(format!("unknown term tag {other:?}"))),
    }
}

fn ruby_to_subject(val: Value) -> Result<NamedOrBlankNode, Error> {
    match ruby_to_term(val)? {
        Term::NamedNode(n) => Ok(n.into()),
        Term::BlankNode(b) => Ok(b.into()),
        _ => Err(err("subject must be an IRI or blank node")),
    }
}

fn ruby_to_graph(ruby: &Ruby, val: Value) -> Result<GraphName, Error> {
    if val.is_nil() {
        return Ok(GraphName::DefaultGraph);
    }
    let _ = ruby;
    match ruby_to_term(val)? {
        Term::NamedNode(n) => Ok(n.into()),
        Term::BlankNode(b) => Ok(b.into()),
        _ => Err(err("graph name must be an IRI, blank node, or nil")),
    }
}

// ---------- oxigraph -> Ruby (tagged tuple) ----------

fn term_to_ruby(ruby: &Ruby, t: &Term) -> Result<RArray, Error> {
    let a = ruby.ary_new();
    match t {
        Term::NamedNode(n) => {
            a.push("uri")?;
            a.push(n.as_str())?;
        }
        Term::BlankNode(b) => {
            a.push("bnode")?;
            a.push(b.as_str())?;
        }
        Term::Literal(l) => {
            a.push("lit")?;
            a.push(l.value())?;
            match l.language() {
                Some(lang) => {
                    a.push(ruby.qnil())?; // datatype implied (rdf:langString)
                    a.push(lang)?;
                }
                None => {
                    a.push(l.datatype().as_str())?;
                    a.push(ruby.qnil())?;
                }
            }
        }
        _ => return Err(err("RDF-star triple terms are not supported")),
    }
    Ok(a)
}

fn subject_to_term(s: &NamedOrBlankNode) -> Result<Term, Error> {
    match s {
        NamedOrBlankNode::NamedNode(n) => Ok(Term::NamedNode(n.clone())),
        NamedOrBlankNode::BlankNode(b) => Ok(Term::BlankNode(b.clone())),
    }
}

fn graph_to_ruby(ruby: &Ruby, g: &GraphName) -> Result<Value, Error> {
    match g {
        GraphName::DefaultGraph => Ok(ruby.qnil().as_value()),
        GraphName::NamedNode(n) => Ok(term_to_ruby(ruby, &Term::NamedNode(n.clone()))?.as_value()),
        GraphName::BlankNode(b) => Ok(term_to_ruby(ruby, &Term::BlankNode(b.clone()))?.as_value()),
    }
}

fn parse_format(format: &str) -> Result<RdfFormat, Error> {
    Ok(match format {
        "turtle" | "ttl" => RdfFormat::Turtle,
        "ntriples" | "nt" => RdfFormat::NTriples,
        "nquads" | "nq" => RdfFormat::NQuads,
        "trig" => RdfFormat::TriG,
        "rdfxml" | "rdf" => RdfFormat::RdfXml,
        "jsonld" | "json" => RdfFormat::JsonLd {
            profile: JsonLdProfileSet::empty(),
        },
        "n3" => RdfFormat::N3,
        other => return Err(err(format!("unknown RDF format {other:?}"))),
    })
}

fn quad_to_ruby(ruby: &Ruby, quad: &Quad) -> Result<RArray, Error> {
    let row = ruby.ary_new();
    row.push(term_to_ruby(ruby, &subject_to_term(&quad.subject)?)?)?;
    row.push(term_to_ruby(ruby, &Term::NamedNode(quad.predicate.clone()))?)?;
    row.push(term_to_ruby(ruby, &quad.object)?)?;
    row.push(graph_to_ruby(ruby, &quad.graph_name)?)?;
    Ok(row)
}

fn ruby_to_quad(val: Value) -> Result<Quad, Error> {
    let ruby = Ruby::get().map_err(err)?;
    let arr = RArray::try_convert(val)?;
    Ok(Quad::new(
        ruby_to_subject(arr.entry(0)?)?,
        ruby_to_named(arr.entry(1)?)?,
        ruby_to_term(arr.entry(2)?)?,
        ruby_to_graph(&ruby, arr.entry(3)?)?,
    ))
}

// ---------- standalone parse / serialize (no store) ----------

// Parse `data` (a string in `format`) into an Array of [s, p, o, g] tagged tuples.
fn parse(data: String, format: String) -> Result<RArray, Error> {
    let ruby = Ruby::get().map_err(err)?;
    let fmt = parse_format(&format)?;
    let out = ruby.ary_new();
    for quad in RdfParser::from_format(fmt).for_reader(data.as_bytes()) {
        out.push(quad_to_ruby(&ruby, &quad.map_err(err)?)?)?;
    }
    Ok(out)
}

// Serialize an Array of [s, p, o, g] tagged tuples to a string in `format`.
fn serialize(quads: RArray, format: String) -> Result<String, Error> {
    let fmt = parse_format(&format)?;
    let mut ser = RdfSerializer::from_format(fmt).for_writer(Vec::<u8>::new());
    for i in 0..quads.len() {
        let quad = ruby_to_quad(quads.entry(i as isize)?)?;
        ser.serialize_quad(&quad).map_err(err)?;
    }
    String::from_utf8(ser.finish().map_err(err)?).map_err(err)
}

// ---------- SHACL validation ----------

fn rudof_format(format: &str) -> Result<RudofFormat, Error> {
    Ok(match format {
        "turtle" | "ttl" => RudofFormat::Turtle,
        "ntriples" | "nt" => RudofFormat::NTriples,
        "nquads" | "nq" => RudofFormat::NQuads,
        "trig" => RudofFormat::TriG,
        "rdfxml" | "rdf" => RudofFormat::Rdfxml,
        "n3" => RudofFormat::N3,
        "jsonld" | "json" => RudofFormat::JsonLd,
        other => return Err(err(format!("unknown RDF format {other:?}"))),
    })
}

// Validate `data` against SHACL `shapes` (both serialized RDF strings). Returns a Ruby Hash:
//   { "conforms" => bool, "violations" => n,
//     "results" => [ { focus, path, value, source, severity, message } ],
//     "text" => "<human-readable report>" }
fn shacl_validate(
    data: String,
    data_format: String,
    shapes: String,
    shapes_format: String,
) -> Result<RHash, Error> {
    let ruby = Ruby::get().map_err(err)?;

    let schema = ShaclDataManager::load(
        &mut Cursor::new(shapes),
        "shapes",
        &rudof_format(&shapes_format)?,
        None,
    )
    .map_err(err)?;

    let data_graph = OxigraphInMemory::from_reader(
        &mut Cursor::new(data),
        "data",
        &rudof_format(&data_format)?,
        None,
        &ReaderMode::default(),
    )
    .map_err(err)?;

    let graph = ShaclGraph::try_from(data_graph).map_err(err)?;
    let mut validator = GraphValidation::new(graph);
    let report = validator
        .validate(&schema, &ShaclValidationMode::Native, &ShaclConfig::default())
        .map_err(err)?;

    let results = ruby.ary_new();
    for r in report.results() {
        let h = ruby.hash_new();
        h.aset("focus", r.focus_node().to_string())?;
        h.aset("severity", format!("{}", r.severity()))?; // Severity: Display
        // Extract just the message text(s) from the MessageMap (its Display wraps them).
        let message = r
            .message()
            .messages()
            .values()
            .cloned()
            .collect::<Vec<_>>()
            .join("; ");
        h.aset("message", message)?;
        h.aset("path", r.path().map(|p| format!("{p:?}")))?; // SHACLPath: no Display, use Debug
        h.aset("value", r.value().map(|v| v.to_string()))?;
        h.aset("source", r.source().map(|s| s.to_string()))?;
        results.push(h)?;
    }

    let out = ruby.hash_new();
    out.aset("conforms", report.conforms())?;
    out.aset("violations", report.results().len())?;
    out.aset("results", results)?;
    out.aset("text", format!("{report}"))?;
    Ok(out)
}

// ---------- Store ----------

#[magnus::wrap(class = "RDF::Oxigraph::Store", free_immediately, size)]
struct Store(OxiStore);

impl Store {
    fn new() -> Result<Self, Error> {
        Ok(Store(OxiStore::new().map_err(err)?))
    }

    fn insert(&self, s: Value, p: Value, o: Value, g: Value) -> Result<bool, Error> {
        let ruby = Ruby::get().map_err(err)?;
        let quad = Quad::new(
            ruby_to_subject(s)?,
            ruby_to_named(p)?,
            ruby_to_term(o)?,
            ruby_to_graph(&ruby, g)?,
        );
        // oxigraph 0.5's insert returns (); recompute "was it new?" for our Ruby API.
        let existed = self.0.contains(&quad).map_err(err)?;
        self.0.insert(&quad).map_err(err)?;
        Ok(!existed)
    }

    fn delete(&self, s: Value, p: Value, o: Value, g: Value) -> Result<bool, Error> {
        let ruby = Ruby::get().map_err(err)?;
        let quad = Quad::new(
            ruby_to_subject(s)?,
            ruby_to_named(p)?,
            ruby_to_term(o)?,
            ruby_to_graph(&ruby, g)?,
        );
        // oxigraph 0.5's remove returns (); recompute "did it exist?" for our Ruby API.
        let existed = self.0.contains(&quad).map_err(err)?;
        self.0.remove(&quad).map_err(err)?;
        Ok(existed)
    }

    fn size(&self) -> Result<usize, Error> {
        self.0.len().map_err(err)
    }

    fn load(&self, data: String, format: String) -> Result<(), Error> {
        self.0
            .load_from_reader(parse_format(&format)?, data.as_bytes())
            .map_err(err)?;
        Ok(())
    }

    // Serialize the entire store to a string in `format`.
    fn dump(&self, format: String) -> Result<String, Error> {
        let mut ser = RdfSerializer::from_format(parse_format(&format)?).for_writer(Vec::<u8>::new());
        for quad in self.0.iter() {
            ser.serialize_quad(&quad.map_err(err)?).map_err(err)?;
        }
        String::from_utf8(ser.finish().map_err(err)?).map_err(err)
    }

    fn each_quad(&self) -> Result<RArray, Error> {
        let ruby = Ruby::get().map_err(err)?;
        let out = ruby.ary_new();
        for quad in self.0.iter() {
            out.push(quad_to_ruby(&ruby, &quad.map_err(err)?)?)?;
        }
        Ok(out)
    }

    // Execute a SPARQL 1.1 Update (INSERT DATA / DELETE DATA / DELETE/INSERT WHERE / LOAD / ...).
    fn update(&self, update: String) -> Result<(), Error> {
        self.0.update(update.as_str()).map_err(err)
    }

    fn query(&self, sparql: String) -> Result<RArray, Error> {
        let ruby = Ruby::get().map_err(err)?;
        let result = ruby.ary_new();
        let query_results = SparqlEvaluator::new()
            .parse_query(&sparql)
            .map_err(err)?
            .on_store(&self.0)
            .execute()
            .map_err(err)?;
        match query_results {
            QueryResults::Boolean(b) => {
                result.push("boolean")?;
                result.push(b)?;
            }
            QueryResults::Solutions(solutions) => {
                let var_names: Vec<String> = solutions
                    .variables()
                    .iter()
                    .map(|v| v.as_str().to_owned())
                    .collect();
                let vars = ruby.ary_new();
                for v in &var_names {
                    vars.push(v.as_str())?;
                }
                let rows = ruby.ary_new();
                for sol in solutions {
                    let sol = sol.map_err(err)?;
                    let row = ruby.ary_new();
                    for vn in &var_names {
                        match sol.get(vn.as_str()) {
                            Some(term) => row.push(term_to_ruby(&ruby, term)?)?,
                            None => row.push(ruby.qnil())?,
                        }
                    }
                    rows.push(row)?;
                }
                result.push("solutions")?;
                result.push(vars)?;
                result.push(rows)?;
            }
            QueryResults::Graph(triples) => {
                let arr = ruby.ary_new();
                for triple in triples {
                    let triple = triple.map_err(err)?;
                    let row = ruby.ary_new();
                    row.push(term_to_ruby(&ruby, &subject_to_term(&triple.subject)?)?)?;
                    row.push(term_to_ruby(&ruby, &Term::NamedNode(triple.predicate.clone()))?)?;
                    row.push(term_to_ruby(&ruby, &triple.object)?)?;
                    arr.push(row)?;
                }
                result.push("graph")?;
                result.push(arr)?;
            }
        }
        Ok(result)
    }
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let rdf = ruby.define_module("RDF")?;
    let oxigraph = rdf.define_module("Oxigraph")?;

    // Standalone, store-free format I/O over the tagged-tuple wire format.
    oxigraph.define_singleton_method("parse", function!(parse, 2))?;
    oxigraph.define_singleton_method("serialize", function!(serialize, 2))?;

    // SHACL validation (data, data_format, shapes, shapes_format) -> report Hash.
    oxigraph.define_singleton_method("shacl_validate", function!(shacl_validate, 4))?;

    let store = oxigraph.define_class("Store", ruby.class_object())?;
    store.define_singleton_method("new", function!(Store::new, 0))?;
    store.define_method("insert", method!(Store::insert, 4))?;
    store.define_method("delete", method!(Store::delete, 4))?;
    store.define_method("size", method!(Store::size, 0))?;
    store.define_method("load", method!(Store::load, 2))?;
    store.define_method("dump", method!(Store::dump, 1))?;
    store.define_method("each_quad", method!(Store::each_quad, 0))?;
    store.define_method("query", method!(Store::query, 1))?;
    store.define_method("update", method!(Store::update, 1))?;
    Ok(())
}
