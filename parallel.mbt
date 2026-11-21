///|
/// One right-hand side of a simultaneous assignment.
pub(all) struct Assignment {
  target : Int32
  source : Term
  offset : Int64
}

///|
/// Extend the domain with fresh unconstrained dimensions. Internal helper used
/// by simultaneous assignment; the public domain size stays 1..24.
fn Octagon::extend_dimensions(
  self : Octagon,
  extra : Int32,
) -> Octagon raise OctagonError {
  if extra <= 0 {
    return self
  }
  let total = self.dimensions + extra
  if total > 24 {
    raise Limit("simultaneous assignment needs \{total} dimensions, at most 24")
  }
  if self.empty {
    return bottom(total)
  }
  let size = total * 2
  let old = self.dimensions * 2
  let m = Array::makei(size, i => {
    Array::makei(size, j => {
      if i == j {
        0L
      } else if i < old && j < old {
        self.matrix[i][j]
      } else {
        INF
      }
    })
  })
  { dimensions: total, matrix: m, empty: false, }
}

///|
/// Keep only the first `keep` dimensions after a temporary extension.
fn Octagon::shrink_dimensions(
  self : Octagon,
  keep : Int32,
) -> Octagon raise OctagonError {
  if keep == self.dimensions {
    return self
  }
  if keep < 1 || keep > self.dimensions {
    raise Invalid("cannot shrink to \{keep} dimensions")
  }
  if self.empty {
    return bottom(keep)
  }
  let size = keep * 2
  let m = Array::makei(size, i => Array::makei(size, j => self.matrix[i][j]))
  close(keep, m)
}

///|
/// Apply all assignments simultaneously: every right-hand side reads the old
/// state. Targets must be distinct. At most 8 assignments fit in 24 dimensions.
pub fn Octagon::assign_parallel(
  self : Octagon,
  assignments : Array[Assignment],
) -> Octagon raise OctagonError {
  if assignments.length() > 8 {
    raise Limit("at most 8 simultaneous assignments")
  }
  for a in assignments {
    variable(self.dimensions, a.target)
    ignore(term_index(self.dimensions, a.source))
    validate_bound(a.offset)
  }
  for i in 0..<assignments.length() {
    for j in (i + 1)..<assignments.length() {
      if assignments[i].target == assignments[j].target {
        raise Invalid("simultaneous assignments target the same variable")
      }
    }
  }
  if self.empty || assignments.length() == 0 {
    return self
  }
  let base = self.dimensions
  let k = assignments.length()
  let mut s = self.extend_dimensions(k)
  for i in 0..<k {
    s = s.assign(base + i, assignments[i].source, assignments[i].offset)
  }
  for i in 0..<k {
    s = s.assign(assignments[i].target, positive(base + i), 0L)
  }
  let temps : Array[Int32] = Array::makei(k, i => base + i)
  s.forget_many(temps).shrink_dimensions(base)
}

///|
/// Rename variables so that new x_i equals old x_permutation[i]. The
/// permutation must be a bijection over 0..dimensions-1.
pub fn Octagon::rename(
  self : Octagon,
  permutation : Array[Int32],
) -> Octagon raise OctagonError {
  if permutation.length() != self.dimensions {
    raise Invalid(
      "rename permutation length \{permutation.length()} differs from \{self.dimensions}",
    )
  }
  let seen : Array[Bool] = Array::make(self.dimensions, false)
  for p in permutation {
    variable(self.dimensions, p)
    if seen[p] {
      raise Invalid("rename permutation repeats variable \{p}")
    }
    seen[p] = true
  }
  if self.empty {
    return self
  }
  let s = self.canonical()
  let size = self.dimensions * 2
  let map = Array::makei(size, i => permutation[i / 2] * 2 + i % 2)
  let m = Array::makei(size, i => {
    Array::makei(size, j => s.matrix[map[i]][map[j]])
  })
  close(self.dimensions, m)
}

///|
/// Least octagonal upper bound of a non-empty family of compatible states.
pub fn join_all(states : Array[Octagon]) -> Octagon raise OctagonError {
  if states.length() == 0 {
    raise Invalid("join_all needs at least one state")
  }
  let mut acc = states[0]
  for i in 1..<states.length() {
    acc = acc.join(states[i])
  }
  acc
}

///|
/// Exact intersection of a non-empty family of compatible states.
pub fn meet_all(states : Array[Octagon]) -> Octagon raise OctagonError {
  if states.length() == 0 {
    raise Invalid("meet_all needs at least one state")
  }
  let mut acc = states[0]
  for i in 1..<states.length() {
    acc = acc.meet(states[i])
  }
  acc
}
