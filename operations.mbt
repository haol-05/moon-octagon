///|
pub fn Octagon::canonical(self : Octagon) -> Octagon raise OctagonError {
  if self.empty {
    self
  } else {
    close(self.dimensions, clone_matrix(self.matrix))
  }
}

///|
pub fn Octagon::meet(
  self : Octagon,
  other : Octagon,
) -> Octagon raise OctagonError {
  compatible(self, other)
  if self.empty || other.empty {
    return bottom(self.dimensions)
  }
  let m = clone_matrix(self.matrix)
  for i in 0..<m.length() {
    for j in 0..<m.length() {
      if other.matrix[i][j] < m[i][j] {
        m[i][j] = other.matrix[i][j]
      }
    }
  }
  close(self.dimensions, m)
}

///|
/// Least octagonal overapproximation of union. It may include extra integer states.
pub fn Octagon::join(
  self : Octagon,
  other : Octagon,
) -> Octagon raise OctagonError {
  compatible(self, other)
  if self.empty {
    return other.canonical()
  }
  if other.empty {
    return self.canonical()
  }
  let a = self.canonical()
  let b = other.canonical()
  let m = clone_matrix(a.matrix)
  for i in 0..<m.length() {
    for j in 0..<m.length() {
      if b.matrix[i][j] > m[i][j] {
        m[i][j] = b.matrix[i][j]
      }
    }
  }
  close(self.dimensions, m)
}

///|
pub fn Octagon::subset_of(
  self : Octagon,
  other : Octagon,
) -> Bool raise OctagonError {
  compatible(self, other)
  if self.empty {
    return true
  }
  if other.empty {
    return false
  }
  let a = self.canonical()
  for i in 0..<a.matrix.length() {
    for j in 0..<a.matrix.length() {
      if a.matrix[i][j] > other.matrix[i][j] {
        return false
      }
    }
  }
  true
}

///|
pub fn Octagon::equivalent(
  self : Octagon,
  other : Octagon,
) -> Bool raise OctagonError {
  self.subset_of(other) && other.subset_of(self)
}

///|
/// Standard matrix widening. Preserve this raw result as the next left operand.
/// Closing it between widen calls can destroy the finite-chain guarantee.
/// Query methods close a copy without modifying this representation.
pub fn Octagon::widen(
  self : Octagon,
  next : Octagon,
) -> Octagon raise OctagonError {
  compatible(self, next)
  if self.empty {
    return next.canonical()
  }
  if next.empty {
    return self
  }
  let b = next.canonical()
  let m = clone_matrix(self.matrix)
  for i in 0..<m.length() {
    for j in 0..<m.length() {
      if b.matrix[i][j] > m[i][j] {
        m[i][j] = INF
      }
    }
  }
  { dimensions: self.dimensions, matrix: m, empty: false, }
}

///|
/// Existential projection. Consequences among retained variables survive.
pub fn Octagon::forget(
  self : Octagon,
  target : Int32,
) -> Octagon raise OctagonError {
  variable(self.dimensions, target)
  if self.empty {
    return self
  }
  let s = self.canonical()
  let m = clone_matrix(s.matrix)
  for i in 0..<m.length() {
    for j in 0..<m.length() {
      if i / 2 == target || j / 2 == target {
        m[i][j] = if i == j { 0L } else { INF }
      }
    }
  }
  close(self.dimensions, m)
}

///|
/// Exact octagonal image of x[target] := sign * x[source] + offset.
/// Simultaneous RHS semantics also handles target == source.
pub fn Octagon::assign(
  self : Octagon,
  target : Int32,
  source : Term,
  offset : Int64,
) -> Octagon raise OctagonError {
  variable(self.dimensions, target)
  ignore(term_index(self.dimensions, source))
  validate_bound(offset)
  if self.empty {
    return self
  }
  let s = self.canonical()
  let size = s.matrix.length()
  let map = Array::makei(size, i => {
    if i / 2 == target {
      2 * source.variable +
      (if (i % 2 == 0 && source.sign == 1) || (i % 2 == 1 && source.sign == -1) {
        0
      } else {
        1
      })
    } else {
      i
    }
  })
  let delta = Array::makei(size, i => {
    if i / 2 == target {
      if i % 2 == 0 {
        offset
      } else {
        -offset
      }
    } else {
      0L
    }
  })
  let m = Array::makei(size, i => {
    Array::makei(size, j => plus(s.matrix[map[i]][map[j]], delta[i] - delta[j]))
  })
  close(self.dimensions, m)
}

///|
pub fn Octagon::set_constant(
  self : Octagon,
  target : Int32,
  value : Int64,
) -> Octagon raise OctagonError {
  validate_bound(value)
  self.forget(target).refine([lower(target, value), upper(target, value)])
}

///|
/// Export a complete canonical conjunction; callers receive fresh owned arrays.
pub fn Octagon::constraints(
  self : Octagon,
) -> Array[Constraint] raise OctagonError {
  if self.empty {
    raise Invalid(
      "bottom cannot be exported as a finite satisfiable conjunction",
    )
  }
  let s = self.canonical()
  let result : Array[Constraint] = []
  for i in 0..<s.matrix.length() {
    for j in 0..<s.matrix.length() {
      let b = s.matrix[i][j]
      if i != j && b != INF {
        result.push({
          left: { variable: i / 2, sign: if i % 2 == 0 { 1 } else { -1 }, },
          right: Some({
            variable: j / 2,
            sign: if j % 2 == 0 {
              -1
            } else {
              1
            },
          }),
          bound: b,
        })
      }
    }
  }
  result
}
