///|
#derive(@debug.Debug)
pub suberror OctagonError {
  Invalid(String)
  Limit(String)
  Arithmetic(String)
}

///|
/// A signed variable term. Sign must be +1 or -1.
#derive(Eq, @debug.Debug, ToJson)
pub(all) struct Term {
  variable : Int32
  sign : Int32
}

///|
/// left + right <= bound. None makes this a unary constraint.
#derive(Eq, @debug.Debug, ToJson)
pub(all) struct Constraint {
  left : Term
  right : Term?
  bound : Int64
}

///|
/// None means unbounded; an empty domain has no interval.
#derive(Eq, @debug.Debug, ToJson)
pub(all) struct Interval {
  lower : Int64?
  upper : Int64?
}

///|
/// Immutable domain over mathematical integers, independent of machine overflow semantics.
pub struct Octagon {
  dimensions : Int32
  matrix : Array[Array[Int64]]
  empty : Bool
}

///|
#derive(Eq, @debug.Debug, ToJson)
pub(all) struct Conflict {
  indices : Array[Int32]
  checks : Int32
}

///|
/// Proven means implication over the abstract state, not concrete reachability.
#derive(@debug.Debug, ToJson)
pub enum Verdict {
  Vacuous
  Proven
  Refuted(Array[Int64])
}

///|
const INF : Int64 = 4000000000000000L

///|
const MAX_FINITE : Int64 = 1000000000000000L

///|
fn plus(a : Int64, b : Int64) -> Int64 raise OctagonError {
  if a == INF || b == INF {
    return INF
  }
  let c = a + b
  if c < -MAX_FINITE || c > MAX_FINITE {
    raise Arithmetic("derived bound exceeds exact arithmetic budget")
  }
  c
}

///|
fn half_floor(v : Int64) -> Int64 {
  let q = v / 2L
  if v < 0L && v % 2L != 0L {
    q - 1L
  } else {
    q
  }
}

///|
fn complement(i : Int32) -> Int32 {
  i ^ 1
}

///|
fn clone_matrix(m : Array[Array[Int64]]) -> Array[Array[Int64]] {
  m.map(row => row.copy())
}

///|
fn validate_dimensions(n : Int32) -> Unit raise OctagonError {
  if n < 1 || n > 24 {
    raise Limit("dimensions must be between 1 and 24")
  }
}

///|
fn variable(n : Int32, i : Int32) -> Unit raise OctagonError {
  if i < 0 || i >= n {
    raise Invalid("variable index out of range")
  }
}

///|
fn term_index(n : Int32, t : Term) -> Int32 raise OctagonError {
  variable(n, t.variable)
  if t.sign != 1 && t.sign != -1 {
    raise Invalid("term sign must be 1 or -1")
  }
  2 * t.variable + (if t.sign == 1 { 0 } else { 1 })
}

///|
fn validate_bound(v : Int64) -> Unit raise OctagonError {
  if v < -1000000000L || v > 1000000000L {
    raise Limit("input bound or offset exceeds +/- 1000000000")
  }
}

///|
fn validate_constraint(n : Int32, c : Constraint) -> Unit raise OctagonError {
  ignore(term_index(n, c.left))
  if c.right is Some(t) {
    ignore(term_index(n, t))
  }
  let bound_limit = if c.right is None { MAX_FINITE / 2L } else { MAX_FINITE }
  if c.bound < -bound_limit || c.bound > bound_limit {
    raise Limit("constraint exceeds exact arithmetic budget")
  }
}

///|
pub fn positive(i : Int32) -> Term {
  { variable: i, sign: 1, }
}

///|
pub fn negative(i : Int32) -> Term {
  { variable: i, sign: -1, }
}

///|
pub fn upper(i : Int32, value : Int64) -> Constraint {
  { left: positive(i), right: None, bound: value, }
}

///|
pub fn lower(i : Int32, value : Int64) -> Constraint {
  // A caller-supplied Int64 minimum is deliberately rejected during validation.
  {
    left: negative(i),
    right: None,
    bound: if value == -9223372036854775808L {
      value
    } else {
      -value
    },
  }
}

///|
pub fn relation(a : Term, b : Term, bound : Int64) -> Constraint {
  { left: a, right: Some(b), bound, }
}

///|
pub fn top(n : Int32) -> Octagon raise OctagonError {
  validate_dimensions(n)
  let size = n * 2
  let m = Array::makei(size, i => {
    Array::makei(size, j => if i == j { 0L } else { INF })
  })
  { dimensions: n, matrix: m, empty: false, }
}

///|
pub fn bottom(n : Int32) -> Octagon raise OctagonError {
  let s = top(n)
  { ..s, empty: true, }
}

///|
pub fn Octagon::size(self : Octagon) -> Int32 {
  self.dimensions
}

///|
pub fn Octagon::is_bottom(self : Octagon) -> Bool {
  self.empty
}

///|
pub fn Octagon::is_top(self : Octagon) -> Bool {
  if self.empty {
    return false
  }
  for i in 0..<self.matrix.length() {
    for j in 0..<self.matrix.length() {
      if i != j && self.matrix[i][j] != INF {
        return false
      }
    }
  }
  true
}

///|
fn compatible(a : Octagon, b : Octagon) -> Unit raise OctagonError {
  if a.dimensions != b.dimensions {
    raise Invalid("domain dimensions differ")
  }
}
