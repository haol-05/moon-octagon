///|
fn text(r : @oct.Interval) -> String {
  match (r.lower, r.upper) {
    (Some(lo), Some(hi)) => "[\{lo}, \{hi}]"
    (Some(lo), None) => "[\{lo}, inf)"
    (None, Some(hi)) => "(-inf, \{hi}]"
    (None, None) => "(-inf, inf)"
  }
}

///|
/// Contrast independent interval reasoning with the shared octagonal bound.
fn main {
  try {
    let envelope = @oct.from_constraints(2, [
      @oct.lower(0, 0L),
      @oct.lower(1, 0L),
      @oct.upper(0, 100L),
      @oct.upper(1, 100L),
      @oct.relation(@oct.positive(0), @oct.positive(1), 100L),
    ])
    println("Budget shared by a primary and a replica: x0 + x1 <= 100")
    match envelope.interval(0) {
      Some(r) => println("x0 in \{text(r)}")
      None => println("x0 empty")
    }
    match envelope.interval(1) {
      Some(r) => println("x1 in \{text(r)}")
      None => println("x1 empty")
    }
    println("Interval-only sum bound is 200: it drops the shared budget.")
    match envelope.bound(@oct.positive(0), Some(@oct.positive(1))) {
      Some(v) => println("Octagon sum bound: \{v}")
      None => println("Octagon sum bound: unbounded")
    }
    println("Canonical render: \{envelope.render()}")
    println("x0=100, x1=100 accepted: \{envelope.contains([100L, 100L])}")
    match envelope.witness() {
      Some(w) => println("A concrete point: (\{w[0]}, \{w[1]})")
      None => println("no witness")
    }
  } catch {
    _ => println("Example failed")
  }
}
