///|
fn obj(
  value : Json,
  allowed : Array[String],
) -> Map[String, Json] raise OctagonError {
  let m = match value {
    Object(m) => m
    _ => raise Invalid("expected object")
  }
  for k in m.keys() {
    if !allowed.contains(k) {
      raise Invalid("unknown field: \{k}")
    }
  }
  m
}

///|
fn get(m : Map[String, Json], key : String) -> Json raise OctagonError {
  match m.get(key) {
    Some(v) => v
    None => raise Invalid("missing field: \{key}")
  }
}

///|
fn str(value : Json) -> String raise OctagonError {
  match value {
    String(s) => s
    _ => raise Invalid("expected string")
  }
}

///|
fn arr(value : Json) -> Array[Json] raise OctagonError {
  match value {
    Array(a) => a
    _ => raise Invalid("expected array")
  }
}

///|
fn integer(value : Json) -> Int64 raise OctagonError {
  match value {
    Number(d, repr=representation) => {
      if representation is Some(raw) {
        for ch in raw.iter() {
          if ch == '.' || ch == 'e' || ch == 'E' {
            raise Invalid(
              "expected integer literal without fraction or exponent",
            )
          }
        }
      }
      if d.is_inf() ||
        d.is_nan() ||
        d < -1000000000.0 ||
        d > 1000000000.0 ||
        d.trunc() != d {
        raise Invalid("expected an integer in +/- 1000000000")
      }
      d.to_int64()
    }
    _ => raise Invalid("expected integer")
  }
}

///|
fn read_term(value : Json) -> Term raise OctagonError {
  let m = obj(value, ["variable", "sign"])
  {
    variable: integer(get(m, "variable")).to_int(),
    sign: integer(get(m, "sign")).to_int(),
  }
}

///|
fn read_constraint(value : Json) -> Constraint raise OctagonError {
  let m = obj(value, ["left", "right", "bound"])
  {
    left: read_term(get(m, "left")),
    right: match m.get("right") {
      None | Some(Null) => None
      Some(v) => Some(read_term(v))
    },
    bound: integer(get(m, "bound")),
  }
}

///|
fn read_constraints(value : Json) -> Array[Constraint] raise OctagonError {
  let a = arr(value)
  if a.length() > 512 {
    raise Limit("at most 512 constraints, got \{a.length()}")
  }
  a.map(read_constraint)
}

///|
fn read_transfers(value : Json) -> Array[Transfer] raise OctagonError {
  let a = arr(value)
  if a.length() > 128 {
    raise Limit("at most 128 transfers, got \{a.length()}")
  }
  a.map(v => {
    let m = match v {
      Object(m) => m
      _ => raise Invalid("expected transfer object")
    }
    match str(get(m, "op")) {
      "guard" => {
        ignore(obj(v, ["op", "constraints"]))
        Guard(read_constraints(get(m, "constraints")))
      }
      "assign" => {
        ignore(obj(v, ["op", "target", "source", "offset"]))
        Assign(
          integer(get(m, "target")).to_int(),
          read_term(get(m, "source")),
          integer(get(m, "offset")),
        )
      }
      "set" => {
        ignore(obj(v, ["op", "target", "value"]))
        Set(integer(get(m, "target")).to_int(), integer(get(m, "value")))
      }
      "forget" => {
        ignore(obj(v, ["op", "target"]))
        Forget(integer(get(m, "target")).to_int())
      }
      _ => raise Invalid("unknown transfer operation")
    }
  })
}

///|
fn optional_integer(
  m : Map[String, Json],
  name : String,
  default : Int32,
) -> Int32 raise OctagonError {
  match m.get(name) {
    None => default
    Some(v) => integer(v).to_int()
  }
}

///|
/// Stable JSON output with explicit empty/unbounded states and decimal Int64 strings.
pub fn Octagon::report(self : Octagon) -> Json raise OctagonError {
  if self.empty {
    return { "state": "empty" }
  }
  let intervals : Array[Json] = Array::makei(self.dimensions, i => {
    match self.interval(i) {
      None => @json.null
      Some(r) =>
        { "lower": optional_bound(r.lower), "upper": optional_bound(r.upper) }
    }
  })
  let witness = match self.witness() {
    None => @json.null
    Some(v) => @json.to_json(v)
  }
  {
    "state": "nonempty",
    "intervals": @json.to_json(intervals),
    "witness": witness,
  }
}

///|
fn dispatch(value : Json) -> Json raise OctagonError {
  let m = match value {
    Object(m) => m
    _ => raise Invalid("request must be object")
  }
  let op = str(get(m, "op"))
  let allowed = [
    "op", "dimensions", "constraints", "queries", "transfers", "other", "guard",
    "body", "max_iterations", "widen_after", "narrowing_steps", "max_checks",
  ]
  ignore(obj(value, allowed))
  // Operation-specific fields are checked below to prevent silently ignored options.
  let n = integer(get(m, "dimensions")).to_int()
  let cs = read_constraints(get(m, "constraints"))
  let s = from_constraints(n, cs)
  match op {
    "analyze" => {
      ignore(obj(value, ["op", "dimensions", "constraints", "queries"]))
      let queries = match m.get("queries") {
        None => []
        Some(v) => read_constraints(v)
      }
      let verdicts = s.check_all(queries)
      let results : Array[Json] = Array::makei(queries.length(), i => {
        let c = queries[i]
        match verdicts[i] {
          Vacuous => { "verdict": "vacuous", "bound": @json.null }
          Proven =>
            {
              "verdict": "proven",
              "bound": optional_bound(s.bound(c.left, c.right)),
            }
          Refuted(v) =>
            {
              "verdict": "refuted",
              "bound": optional_bound(s.bound(c.left, c.right)),
              "countermodel": @json.to_json(v),
            }
        }
      })
      { "domain": s.report(), "queries": @json.to_json(results) }
    }
    "transfer" => {
      ignore(obj(value, ["op", "dimensions", "constraints", "transfers"]))
      s.execute(read_transfers(get(m, "transfers"))).report()
    }
    "join" | "meet" => {
      ignore(obj(value, ["op", "dimensions", "constraints", "other"]))
      let t = from_constraints(n, read_constraints(get(m, "other")))
      (if op == "join" { s.join(t) } else { s.meet(t) }).report()
    }
    "conflict" => {
      ignore(obj(value, ["op", "dimensions", "constraints", "max_checks"]))
      let c = explain_conflict(
        n,
        cs,
        max_checks=optional_integer(m, "max_checks", 1024),
      )
      let texts : Array[String] = match c {
        None => []
        Some(e) => e.indices.map(k => render_constraint(cs[k]))
      }
      {
        "conflict": match c {
          None => @json.null
          Some(e) => @json.to_json(e)
        },
        "constraints": @json.to_json(texts),
        "verified": @json.to_json(
          match c {
            None => false
            Some(e) => verify_conflict(n, cs, e)
          },
        ),
      }
    }
    "loop" => {
      ignore(
        obj(value, [
          "op", "dimensions", "constraints", "guard", "body", "max_iterations", "widen_after",
          "narrowing_steps",
        ]),
      )
      let guards = read_constraints(get(m, "guard"))
      let body = read_transfers(get(m, "body"))
      let r = analyze_loop(
        s,
        guards,
        body,
        max_iterations=optional_integer(m, "max_iterations", 64),
        widen_after=optional_integer(m, "widen_after", 2),
        narrowing_steps=optional_integer(m, "narrowing_steps", 2),
      )
      {
        "status": @json.to_json(
          match r.status {
            Inductive => "inductive"
            BudgetExhausted => "budget_exhausted"
          },
        ),
        "head": r.head.report(),
        "iterations": @json.to_json(r.iterations),
        "verified": @json.to_json(
          match r.status {
            Inductive => verify_invariant(s, r.head, guards, body)
            BudgetExhausted => false
          },
        ),
      }
    }
    _ => raise Invalid("unknown operation: \{op}")
  }
}

///|
/// Pure bounded JSON entry. Duplicate object keys are rejected by the core parser.
pub fn process_json(input : String) -> String {
  if input.length() > 200000 {
    return encode({
      "ok": false,
      "code": "limit",
      "message": "request exceeds 200000 UTF-16 units",
    })
  }
  let value = @json.parse(
    input,
    max_nesting_depth=32,
    reject_duplicate_keys=true,
    preserve_number_repr=true,
  ) catch {
    _ =>
      return encode({ "ok": false, "code": "json", "message": "invalid JSON" })
  }
  try {
    let result = dispatch(value)
    encode({ "ok": true, "result": result })
  } catch {
    Invalid(message) =>
      encode({ "ok": false, "code": "invalid", "message": message })
    Limit(message) =>
      encode({ "ok": false, "code": "limit", "message": message })
    Arithmetic(message) =>
      encode({ "ok": false, "code": "arithmetic", "message": message })
  }
}

///|
fn encode(value : Json) -> String {
  value.stringify()
}

///|
fn optional_bound(value : Int64?) -> Json {
  match value {
    None => @json.null
    Some(v) => @json.to_json(v)
  }
}

///|
/// Independent results for up to 64 requests, including per-item errors.
pub fn process_batch_json(input : String) -> String {
  if input.length() > 1000000 {
    return encode({
      "ok": false,
      "code": "limit",
      "message": "batch exceeds 1000000 UTF-16 units",
    })
  }
  let value = @json.parse(
    input,
    max_nesting_depth=32,
    reject_duplicate_keys=true,
    preserve_number_repr=true,
  ) catch {
    _ =>
      return encode({
        "ok": false,
        "code": "json",
        "message": "invalid batch JSON",
      })
  }
  let requests = match value {
    Array(a) => a
    _ =>
      return encode({
        "ok": false,
        "code": "invalid",
        "message": "batch must be array",
      })
  }
  if requests.length() > 64 {
    return encode({
      "ok": false,
      "code": "limit",
      "message": "at most 64 batch items",
    })
  }
  let results = requests.map(v => {
    let result = process_json(v.stringify())
    @json.parse(result) catch {
      _ => { "ok": false, "code": "internal" }
    }
  })
  encode(@json.to_json(results))
}
