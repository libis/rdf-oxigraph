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

use magnus::{function, method, prelude::*, value::ReprValue, Error, RArray, Ruby, TryConvert, Value};
use oxigraph::io::RdfFormat;
use oxigraph::model::{BlankNode, GraphName, Literal, NamedNode, Quad, Subject, Term};
use oxigraph::sparql::QueryResults;
use oxigraph::store::Store as OxiStore;

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

fn ruby_to_subject(val: Value) -> Result<Subject, Error> {
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

fn subject_to_term(s: &Subject) -> Result<Term, Error> {
    match s {
        Subject::NamedNode(n) => Ok(Term::NamedNode(n.clone())),
        Subject::BlankNode(b) => Ok(Term::BlankNode(b.clone())),
        _ => Err(err("RDF-star subject terms are not supported")),
    }
}

fn graph_to_ruby(ruby: &Ruby, g: &GraphName) -> Result<Value, Error> {
    match g {
        GraphName::DefaultGraph => Ok(ruby.qnil().as_value()),
        GraphName::NamedNode(n) => Ok(term_to_ruby(ruby, &Term::NamedNode(n.clone()))?.as_value()),
        GraphName::BlankNode(b) => Ok(term_to_ruby(ruby, &Term::BlankNode(b.clone()))?.as_value()),
    }
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
        self.0.insert(&quad).map_err(err)
    }

    fn delete(&self, s: Value, p: Value, o: Value, g: Value) -> Result<bool, Error> {
        let ruby = Ruby::get().map_err(err)?;
        let quad = Quad::new(
            ruby_to_subject(s)?,
            ruby_to_named(p)?,
            ruby_to_term(o)?,
            ruby_to_graph(&ruby, g)?,
        );
        self.0.remove(&quad).map_err(err)
    }

    fn size(&self) -> Result<usize, Error> {
        self.0.len().map_err(err)
    }

    fn load(&self, data: String, format: String) -> Result<(), Error> {
        let fmt = match format.as_str() {
            "turtle" | "ttl" => RdfFormat::Turtle,
            "ntriples" | "nt" => RdfFormat::NTriples,
            "nquads" | "nq" => RdfFormat::NQuads,
            "trig" => RdfFormat::TriG,
            "rdfxml" | "rdf" => RdfFormat::RdfXml,
            other => return Err(err(format!("unknown RDF format {other:?}"))),
        };
        self.0.load_from_reader(fmt, data.as_bytes()).map_err(err)?;
        Ok(())
    }

    fn each_quad(&self) -> Result<RArray, Error> {
        let ruby = Ruby::get().map_err(err)?;
        let out = ruby.ary_new();
        for quad in self.0.iter() {
            let quad = quad.map_err(err)?;
            let row = ruby.ary_new();
            row.push(term_to_ruby(&ruby, &subject_to_term(&quad.subject)?)?)?;
            row.push(term_to_ruby(&ruby, &Term::NamedNode(quad.predicate.clone()))?)?;
            row.push(term_to_ruby(&ruby, &quad.object)?)?;
            row.push(graph_to_ruby(&ruby, &quad.graph_name)?)?;
            out.push(row)?;
        }
        Ok(out)
    }

    fn query(&self, sparql: String) -> Result<RArray, Error> {
        let ruby = Ruby::get().map_err(err)?;
        let result = ruby.ary_new();
        match self.0.query(&sparql).map_err(err)? {
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

    let store = oxigraph.define_class("Store", ruby.class_object())?;
    store.define_singleton_method("new", function!(Store::new, 0))?;
    store.define_method("insert", method!(Store::insert, 4))?;
    store.define_method("delete", method!(Store::delete, 4))?;
    store.define_method("size", method!(Store::size, 0))?;
    store.define_method("load", method!(Store::load, 2))?;
    store.define_method("each_quad", method!(Store::each_quad, 0))?;
    store.define_method("query", method!(Store::query, 1))?;
    Ok(())
}
