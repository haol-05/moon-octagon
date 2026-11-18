///|
fn interval_text(r : Interval) -> String {
  match (r.lower, r.upper) {
    (None, None) => "(-inf, inf)"
    (Some(lo), None) => "[\{lo}, inf)"
    (None, Some(hi)) => "(-inf, \{hi}]"
    (Some(lo), Some(hi)) => "[\{lo}, \{hi}]"
  }
}

///|
fn term_text(t : Term, first : Bool) -> String {
  if first {
    if t.sign == 1 {
      "x\{t.variable}"
    } else {
      "-x\{t.variable}"
    }
  } else if t.sign == 1 {
    " + x\{t.variable}"
  } else {
    " - x\{t.variable}"
  }
}

///|
/// Human-readable form of one constraint, using the same signed-sum syntax as
/// `Octagon::render`. Bounds are printed exactly as stored.
pub fn render_constraint(c : Constraint) -> String {
  let sb = StringBuilder()
  sb.write(term_text(c.left, true))
  match c.right {
    Some(t) => sb.write(term_text(t, false))
    None => ()
  }
  sb.write(" <= \{c.bound}")
  sb.to_string()
}

///|
/// Stable single-line rendering for logs and examples: per-variable intervals
/// followed by every non-redundant binary bound of the canonical conjunction.
/// Only the four signed sums are printed because the flipped entries are their
/// closure mirrors. Use `constraints` or `report` for machine output.
pub fn Octagon::render(self : Octagon) -> String raise OctagonError {
  if self.empty {
    return "bottom(\{self.dimensions})"
  }
  if self.is_top() {
    return "top(\{self.dimensions})"
  }
  let s = self.canonical()
  let sb = StringBuilder()
  let ranges = s.intervals()
  for i in 0..<self.dimensions {
    if i > 0 {
      sb.write("; ")
    }
    sb.write("x\{i} in ")
    match ranges[i] {
      Some(r) => sb.write(interval_text(r))
      None => sb.write("(-inf, inf)")
    }
  }
  for i in 0..<self.dimensions {
    for j in (i + 1)..<self.dimensions {
      let plus = s.matrix[2 * i][2 * j + 1]
      if plus != INF {
        sb.write("; x\{i}+x\{j}<=\{plus}")
      }
      let diff = s.matrix[2 * i][2 * j]
      if diff != INF {
        sb.write("; x\{i}-x\{j}<=\{diff}")
      }
      let neg_diff = s.matrix[2 * i + 1][2 * j + 1]
      if neg_diff != INF {
        sb.write("; -x\{i}+x\{j}<=\{neg_diff}")
      }
      let neg_plus = s.matrix[2 * i + 1][2 * j]
      if neg_plus != INF {
        sb.write("; -x\{i}-x\{j}<=\{neg_plus}")
      }
    }
  }
  sb.to_string()
}
