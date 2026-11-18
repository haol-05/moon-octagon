///|
/// Deterministically fix one variable at a time using integer tight closure.
/// A concrete witness is checked against the original domain before return.
pub fn Octagon::witness(self : Octagon) -> Array[Int64]? raise OctagonError {
  if self.empty {
    return None
  }
  let mut s = self.canonical()
  let values : Array[Int64] = []
  for i in 0..<self.dimensions {
    let range = match s.interval(i) {
      Some(r) => r
      None => raise Arithmetic("unexpected empty projection")
    }
    let value = match (range.lower, range.upper) {
      (Some(lo), _) if lo > 0L => lo
      (_, Some(hi)) if hi < 0L => hi
      _ => 0L
    }
    values.push(value)
    // Derived coordinates may exceed input bounds, so insert equality at DBM level.
    let m = clone_matrix(s.matrix)
    m[2 * i][2 * i + 1] = value * 2L
    m[2 * i + 1][2 * i] = -value * 2L
    s = close(self.dimensions, m)
    if s.empty {
      raise Arithmetic("witness construction lost integer consistency")
    }
  }
  if !self.contains(values) {
    raise Arithmetic("witness failed independent membership check")
  }
  Some(values)
}

///|
pub fn Octagon::check(
  self : Octagon,
  c : Constraint,
) -> Verdict raise OctagonError {
  validate_constraint(self.dimensions, c)
  if self.empty {
    return Vacuous
  }
  if self.entails(c) {
    return Proven
  }
  let negated : Constraint = {
    left: { variable: c.left.variable, sign: -c.left.sign, },
    right: c.right.map(t => { variable: t.variable, sign: -t.sign, }),
    bound: -c.bound - 1L,
  }
  // Negating an input endpoint may produce 1000000001, still safely exact.
  let m = clone_matrix(self.matrix)
  let i = term_index(self.dimensions, negated.left)
  let (j, b) = match negated.right {
    None => (complement(i), negated.bound * 2L)
    Some(t) => (complement(term_index(self.dimensions, t)), negated.bound)
  }
  if b < m[i][j] {
    m[i][j] = b
    m[complement(j)][complement(i)] = b
  }
  let s = close(self.dimensions, m)
  let values = match s.witness() {
    Some(v) => v
    None => raise Arithmetic("non-entailed constraint has no countermodel")
  }
  if satisfies(values, c) || !self.contains(values) {
    raise Arithmetic("countermodel validation failed")
  }
  Refuted(values)
}

///|
/// Returns an inclusion-minimal inconsistent subset of original constraint indices.
/// This is not a minimum-cardinality subset; work is explicitly budgeted.
pub fn explain_conflict(
  n : Int32,
  constraints : Array[Constraint],
  max_checks~ : Int32 = 1024,
) -> Conflict? raise OctagonError {
  if constraints.length() > 512 {
    raise Limit("at most 512 constraints for conflict minimization")
  }
  if max_checks < 1 || max_checks > 1024 {
    raise Limit("conflict budget must be 1..1024")
  }
  if !from_constraints(n, constraints).empty {
    return None
  }
  let mut checks = 1
  let mut indices = Array::makei(constraints.length(), i => i)
  let mut i = 0
  while i < indices.length() {
    if checks >= max_checks {
      raise Limit("conflict minimization budget exhausted")
    }
    let candidate : Array[Int32] = []
    for j in 0..<indices.length() {
      if i != j {
        candidate.push(indices[j])
      }
    }
    let trial = from_constraints(n, candidate.map(k => constraints[k]))
    checks = checks + 1
    if trial.empty {
      indices = candidate
    } else {
      i = i + 1
    }
  }
  Some({ indices, checks, })
}

///|
/// Rebuilds subsets from original inputs, checking inconsistency and every deletion.
pub fn verify_conflict(
  n : Int32,
  constraints : Array[Constraint],
  evidence : Conflict,
) -> Bool raise OctagonError {
  if constraints.length() > 512 {
    raise Limit("at most 512 constraints for conflict verification")
  }
  ignore(from_constraints(n, constraints))
  if evidence.indices.length() == 0 {
    return false
  }
  let selected : Array[Constraint] = []
  let seen : Map[Int32, Bool] = Map([])
  for i in evidence.indices {
    if i < 0 || i >= constraints.length() || seen.contains(i) {
      return false
    }
    seen[i] = true
    selected.push(constraints[i])
  }
  if !from_constraints(n, selected).empty {
    return false
  }
  for i in 0..<selected.length() {
    let trial : Array[Constraint] = []
    for j in 0..<selected.length() {
      if i != j {
        trial.push(selected[j])
      }
    }
    if from_constraints(n, trial).empty {
      return false
    }
  }
  true
}
