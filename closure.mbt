///|
/// m[i][j] bounds signed(i) - signed(j). Coherence is maintained by all constructors.
fn close(n : Int32, m : Array[Array[Int64]]) -> Octagon raise OctagonError {
  let size = n * 2
  for k in 0..<size {
    for i in 0..<size {
      if m[i][k] != INF {
        for j in 0..<size {
          let v = plus(m[i][k], m[k][j])
          if v < m[i][j] {
            m[i][j] = v
          }
        }
      }
    }
    for i in 0..<size {
      if m[i][i] < 0L {
        return bottom(n)
      }
    }
  }
  // Integer consistency: opposite unary bounds must admit an integer.
  for i in 0..<size {
    let a = m[i][complement(i)]
    let b = m[complement(i)][i]
    if a != INF && b != INF && half_floor(a) + half_floor(b) < 0L {
      return bottom(n)
    }
  }
  // Tight closure theorem: after ordinary closure, floor unary halves and strengthen.
  let halves = Array::makei(size, i => {
    let v = m[i][complement(i)]
    if v == INF {
      INF
    } else {
      half_floor(v)
    }
  })
  for i in 0..<size {
    for j in 0..<size {
      let v = plus(halves[i], halves[complement(j)])
      if v < m[i][j] {
        m[i][j] = v
      }
    }
  }
  { dimensions: n, matrix: m, empty: false, }
}

///|
fn insert(
  m : Array[Array[Int64]],
  n : Int32,
  c : Constraint,
) -> Unit raise OctagonError {
  validate_constraint(n, c)
  let i = term_index(n, c.left)
  let (j, b) = match c.right {
    None => (complement(i), c.bound * 2L)
    Some(t) => (complement(term_index(n, t)), c.bound)
  }
  if b < m[i][j] {
    m[i][j] = b
    m[complement(j)][complement(i)] = b
  }
}

///|
pub fn from_constraints(
  n : Int32,
  constraints : Array[Constraint],
) -> Octagon raise OctagonError {
  let s = top(n)
  s.refine(constraints)
}

///|
/// Intersection with guards; all inputs validated even for an empty domain.
pub fn Octagon::refine(
  self : Octagon,
  constraints : Array[Constraint],
) -> Octagon raise OctagonError {
  if constraints.length() > 4096 {
    raise Limit(
      "at most 4096 constraints per operation, got \{constraints.length()}",
    )
  }
  let m = clone_matrix(self.matrix)
  for c in constraints {
    insert(m, self.dimensions, c)
  }
  if self.empty {
    return self
  }
  close(self.dimensions, m)
}

///|
pub fn Octagon::interval(
  self : Octagon,
  i : Int32,
) -> Interval? raise OctagonError {
  variable(self.dimensions, i)
  if self.empty {
    return None
  }
  let s = self.canonical()
  let hi = s.matrix[i * 2][i * 2 + 1]
  let lo = s.matrix[i * 2 + 1][i * 2]
  Some({
    lower: if lo == INF {
      None
    } else {
      Some(-half_floor(lo))
    },
    upper: if hi == INF {
      None
    } else {
      Some(half_floor(hi))
    },
  })
}

///|
/// All variable intervals from a single canonicalisation.
/// Entries are `None` only when the domain is empty.
pub fn Octagon::intervals(
  self : Octagon,
) -> Array[Interval?] raise OctagonError {
  let result : Array[Interval?] = []
  if self.empty {
    for _ in 0..<self.dimensions {
      result.push(None)
    }
    return result
  }
  let s = self.canonical()
  for i in 0..<self.dimensions {
    let hi = s.matrix[i * 2][i * 2 + 1]
    let lo = s.matrix[i * 2 + 1][i * 2]
    result.push(
      Some({
        lower: if lo == INF {
          None
        } else {
          Some(-half_floor(lo))
        },
        upper: if hi == INF {
          None
        } else {
          Some(half_floor(hi))
        },
      }),
    )
  }
  result
}

///|
/// Tight upper bound for a signed unary or binary expression. Empty => error.
/// None => expression is unbounded above.
pub fn Octagon::bound(
  self : Octagon,
  a : Term,
  b : Term?,
) -> Int64? raise OctagonError {
  let i = term_index(self.dimensions, a)
  let j = match b {
    Some(t) => complement(term_index(self.dimensions, t))
    None => complement(i)
  }
  if self.empty {
    raise Invalid("an empty domain has no expression bounds")
  }
  let s = self.canonical()
  let v = s.matrix[i][j]
  if v == INF {
    None
  } else {
    Some(if b is None { half_floor(v) } else { v })
  }
}

///|
pub fn Octagon::entails(
  self : Octagon,
  c : Constraint,
) -> Bool raise OctagonError {
  validate_constraint(self.dimensions, c)
  if self.empty {
    return true
  }
  match self.bound(c.left, c.right) {
    Some(b) => b <= c.bound
    None => false
  }
}

///|
/// Direct evaluation of a concrete integer vector, without solving or closure.
pub fn satisfies(
  values : Array[Int64],
  c : Constraint,
) -> Bool raise OctagonError {
  validate_dimensions(values.length())
  validate_constraint(values.length(), c)
  for v in values {
    if v < -MAX_FINITE || v > MAX_FINITE {
      raise Limit("witness coordinate too large")
    }
  }
  let a = values[c.left.variable] * c.left.sign.to_int64()
  let b = match c.right {
    None => 0L
    Some(t) => values[t.variable] * t.sign.to_int64()
  }
  a + b <= c.bound
}

///|
pub fn Octagon::contains(
  self : Octagon,
  values : Array[Int64],
) -> Bool raise OctagonError {
  if values.length() != self.dimensions {
    raise Invalid("witness dimension mismatch")
  }
  for v in values {
    if v < -MAX_FINITE || v > MAX_FINITE {
      raise Limit("witness coordinate too large")
    }
  }
  if self.empty {
    return false
  }
  let signed = Array::makei(self.dimensions * 2, i => {
    if i % 2 == 0 {
      values[i / 2]
    } else {
      -values[i / 2]
    }
  })
  for i in 0..<signed.length() {
    for j in 0..<signed.length() {
      if self.matrix[i][j] != INF && signed[i] - signed[j] > self.matrix[i][j] {
        return false
      }
    }
  }
  true
}
