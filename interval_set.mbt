///|
/// Independent per-variable integer intervals. This cheap layer is what the
/// octagon domain improves on; conversion helpers make the precision gap
/// measurable. All operations return fresh states.
pub struct Box {
  dimensions : Int32
  lower : Array[Int64?]
  upper : Array[Int64?]
  empty : Bool
}

///|
fn box_compatible(a : Box, b : Box) -> Unit raise OctagonError {
  if a.dimensions != b.dimensions {
    raise Invalid("box dimensions differ: \{a.dimensions} vs \{b.dimensions}")
  }
}

///|
fn lower_min(a : Int64?, b : Int64?) -> Int64? {
  match (a, b) {
    (None, _) | (_, None) => None
    (Some(x), Some(y)) => Some(if x < y { x } else { y })
  }
}

///|
fn upper_max(a : Int64?, b : Int64?) -> Int64? {
  match (a, b) {
    (None, _) | (_, None) => None
    (Some(x), Some(y)) => Some(if x > y { x } else { y })
  }
}

///|
fn add_low(a : Int64?, b : Int64?) -> Int64? {
  match (a, b) {
    (Some(x), Some(y)) => Some(x + y)
    _ => None
  }
}

///|
fn add_high(a : Int64?, b : Int64?) -> Int64? {
  match (a, b) {
    (Some(x), Some(y)) => Some(x + y)
    _ => None
  }
}

///|
fn negate(v : Int64?) -> Int64? {
  match v {
    None => None
    Some(x) => Some(-x)
  }
}

///|
pub fn box_top(n : Int32) -> Box raise OctagonError {
  validate_dimensions(n)
  let lower : Array[Int64?] = Array::makei(n, _ => None)
  let upper : Array[Int64?] = Array::makei(n, _ => None)
  { dimensions: n, lower, upper, empty: false, }
}

///|
pub fn box_bottom(n : Int32) -> Box raise OctagonError {
  let b = box_top(n)
  { ..b, empty: true, }
}

///|
pub fn Box::size(self : Box) -> Int32 {
  self.dimensions
}

///|
pub fn Box::is_bottom(self : Box) -> Bool {
  self.empty
}

///|
pub fn Box::is_top(self : Box) -> Bool {
  if self.empty {
    return false
  }
  for i in 0..<self.dimensions {
    if self.lower[i] is Some(_) || self.upper[i] is Some(_) {
      return false
    }
  }
  true
}

///|
pub fn Box::interval(self : Box, i : Int32) -> Interval? raise OctagonError {
  variable(self.dimensions, i)
  if self.empty {
    None
  } else {
    Some({ lower: self.lower[i], upper: self.upper[i], })
  }
}

///|
pub fn Box::contains(
  self : Box,
  values : Array[Int64],
) -> Bool raise OctagonError {
  if values.length() != self.dimensions {
    raise Invalid("box witness dimension mismatch")
  }
  if self.empty {
    return false
  }
  for i in 0..<self.dimensions {
    let v = values[i]
    match self.lower[i] {
      Some(lo) => if v < lo { return false }
      None => ()
    }
    match self.upper[i] {
      Some(hi) => if v > hi { return false }
      None => ()
    }
  }
  true
}

///|
pub fn Box::meet(self : Box, other : Box) -> Box raise OctagonError {
  box_compatible(self, other)
  if self.empty || other.empty {
    return box_bottom(self.dimensions)
  }
  let lower : Array[Int64?] = []
  let upper : Array[Int64?] = []
  for i in 0..<self.dimensions {
    let lo = match (self.lower[i], other.lower[i]) {
      (None, x) => x
      (x, None) => x
      (Some(a), Some(b)) => Some(if a > b { a } else { b })
    }
    let hi = match (self.upper[i], other.upper[i]) {
      (None, x) => x
      (x, None) => x
      (Some(a), Some(b)) => Some(if a < b { a } else { b })
    }
    match (lo, hi) {
      (Some(a), Some(b)) => if a > b { return box_bottom(self.dimensions) }
      _ => ()
    }
    lower.push(lo)
    upper.push(hi)
  }
  { dimensions: self.dimensions, lower, upper, empty: false, }
}

///|
pub fn Box::join(self : Box, other : Box) -> Box raise OctagonError {
  box_compatible(self, other)
  if self.empty {
    return other
  }
  if other.empty {
    return self
  }
  let lower : Array[Int64?] = []
  let upper : Array[Int64?] = []
  for i in 0..<self.dimensions {
    lower.push(lower_min(self.lower[i], other.lower[i]))
    upper.push(upper_max(self.upper[i], other.upper[i]))
  }
  { dimensions: self.dimensions, lower, upper, empty: false, }
}

///|
/// Threshold widening: any endpoint that moves becomes unbounded.
pub fn Box::widen(self : Box, next : Box) -> Box raise OctagonError {
  box_compatible(self, next)
  if self.empty {
    return next
  }
  if next.empty {
    return self
  }
  let lower : Array[Int64?] = []
  let upper : Array[Int64?] = []
  for i in 0..<self.dimensions {
    let lo = self.lower[i]
    let next_lo = next.lower[i]
    lower.push(if lo == next_lo { lo } else { None })
    let hi = self.upper[i]
    let next_hi = next.upper[i]
    upper.push(if hi == next_hi { hi } else { None })
  }
  { dimensions: self.dimensions, lower, upper, empty: false, }
}

///|
pub fn Box::subset_of(self : Box, other : Box) -> Bool raise OctagonError {
  box_compatible(self, other)
  if self.empty {
    return true
  }
  if other.empty {
    return false
  }
  for i in 0..<self.dimensions {
    match (self.lower[i], other.lower[i]) {
      (Some(a), Some(b)) => if a < b { return false }
      (None, Some(_)) => return false
      _ => ()
    }
    match (self.upper[i], other.upper[i]) {
      (Some(a), Some(b)) => if a > b { return false }
      (None, Some(_)) => return false
      _ => ()
    }
  }
  true
}

///|
pub fn Box::equivalent(self : Box, other : Box) -> Bool raise OctagonError {
  self.subset_of(other) && other.subset_of(self)
}

///|
fn box_term_range(b : Box, t : Term) -> (Int64?, Int64?) {
  let lo = b.lower[t.variable]
  let hi = b.upper[t.variable]
  if t.sign == 1 {
    (lo, hi)
  } else {
    (negate(hi), negate(lo))
  }
}

///|
fn box_expr_range(b : Box, c : Constraint) -> (Int64?, Int64?) {
  let (lo, hi) = box_term_range(b, c.left)
  match c.right {
    None => (lo, hi)
    Some(t) => {
      let (rlo, rhi) = box_term_range(b, t)
      (add_low(lo, rlo), add_high(hi, rhi))
    }
  }
}

///|
pub fn Box::entails(self : Box, c : Constraint) -> Bool raise OctagonError {
  validate_constraint(self.dimensions, c)
  if self.empty {
    return true
  }
  let (_, hi) = box_expr_range(self, c)
  match hi {
    Some(v) => v <= c.bound
    None => false
  }
}

///|
pub fn Box::assign(
  self : Box,
  target : Int32,
  source : Term,
  offset : Int64,
) -> Box raise OctagonError {
  variable(self.dimensions, target)
  ignore(term_index(self.dimensions, source))
  validate_bound(offset)
  if self.empty {
    return self
  }
  let (lo, hi) = box_term_range(self, source)
  let new_low = add_low(lo, Some(offset))
  let new_high = add_high(hi, Some(offset))
  let lower = self.lower.copy()
  let upper = self.upper.copy()
  lower[target] = new_low
  upper[target] = new_high
  { dimensions: self.dimensions, lower, upper, empty: false, }
}

///|
pub fn Box::forget(self : Box, target : Int32) -> Box raise OctagonError {
  variable(self.dimensions, target)
  if self.empty {
    return self
  }
  let lower = self.lower.copy()
  let upper = self.upper.copy()
  lower[target] = None
  upper[target] = None
  { dimensions: self.dimensions, lower, upper, empty: false, }
}

///|
pub fn Box::set_constant(
  self : Box,
  target : Int32,
  value : Int64,
) -> Box raise OctagonError {
  variable(self.dimensions, target)
  validate_bound(value)
  if self.empty {
    return self
  }
  let lower = self.lower.copy()
  let upper = self.upper.copy()
  lower[target] = Some(value)
  upper[target] = Some(value)
  { dimensions: self.dimensions, lower, upper, empty: false, }
}

///|
/// Choose a concrete point inside the box, or `None` for the empty box.
pub fn Box::witness(self : Box) -> Array[Int64]? raise OctagonError {
  if self.empty {
    return None
  }
  let values : Array[Int64] = []
  for i in 0..<self.dimensions {
    let mut value = 0L
    match self.lower[i] {
      Some(lo) => if value < lo { value = lo }
      None => ()
    }
    match self.upper[i] {
      Some(hi) => if value > hi { value = hi }
      None => ()
    }
    values.push(value)
  }
  if !self.contains(values) {
    raise Arithmetic("box witness failed membership check")
  }
  Some(values)
}

///|
/// Forget every relation and keep only the independent intervals.
pub fn Octagon::to_box(self : Octagon) -> Box raise OctagonError {
  if self.empty {
    return box_bottom(self.dimensions)
  }
  let ranges = self.intervals()
  let lower : Array[Int64?] = []
  let upper : Array[Int64?] = []
  for i in 0..<self.dimensions {
    match ranges[i] {
      Some(r) => {
        lower.push(r.lower)
        upper.push(r.upper)
      }
      None => {
        lower.push(None)
        upper.push(None)
      }
    }
  }
  { dimensions: self.dimensions, lower, upper, empty: false, }
}

///|
/// Build the weakest octagon containing this box; all relations are dropped.
pub fn Box::to_octagon(self : Box) -> Octagon raise OctagonError {
  if self.empty {
    return bottom(self.dimensions)
  }
  let constraints : Array[Constraint] = []
  for i in 0..<self.dimensions {
    match self.lower[i] {
      Some(lo) => constraints.push(lower(i, lo))
      None => ()
    }
    match self.upper[i] {
      Some(hi) => constraints.push(upper(i, hi))
      None => ()
    }
  }
  from_constraints(self.dimensions, constraints)
}

///|
/// Serialise the box as constraint text accepted by `parse_constraints`.
pub fn Box::to_text(self : Box) -> String raise OctagonError {
  if self.empty {
    raise Invalid("empty box has no finite text form")
  }
  if self.is_top() {
    return ""
  }
  let sb = StringBuilder()
  let mut first = true
  for i in 0..<self.dimensions {
    let line : String? = match (self.lower[i], self.upper[i]) {
      (Some(lo), Some(hi)) => Some("x\{i} in [\{lo}, \{hi}]")
      (Some(lo), None) => Some("x\{i} >= \{lo}")
      (None, Some(hi)) => Some("x\{i} <= \{hi}")
      (None, None) => None
    }
    match line {
      Some(text) => {
        if !first {
          sb.write("\n")
        }
        first = false
        sb.write(text)
      }
      None => ()
    }
  }
  sb.to_string()
}

///|
/// Least box containing every state in a non-empty compatible family.
pub fn box_join_all(states : Array[Box]) -> Box raise OctagonError {
  if states.length() == 0 {
    raise Invalid("box_join_all needs at least one state")
  }
  let mut acc = states[0]
  for i in 1..<states.length() {
    acc = acc.join(states[i])
  }
  acc
}

///|
/// Exact intersection of a non-empty compatible family of boxes.
pub fn box_meet_all(states : Array[Box]) -> Box raise OctagonError {
  if states.length() == 0 {
    raise Invalid("box_meet_all needs at least one state")
  }
  let mut acc = states[0]
  for i in 1..<states.length() {
    acc = acc.meet(states[i])
  }
  acc
}

///|
pub fn Box::render(self : Box) -> String {
  if self.empty {
    return "bottom(\{self.dimensions})"
  }
  if self.is_top() {
    return "top(\{self.dimensions})"
  }
  let sb = StringBuilder()
  for i in 0..<self.dimensions {
    if i > 0 {
      sb.write("; ")
    }
    sb.write("x\{i} in ")
    sb.write(interval_text({ lower: self.lower[i], upper: self.upper[i], }))
  }
  sb.to_string()
}
