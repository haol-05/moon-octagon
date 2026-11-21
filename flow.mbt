///|
/// Sequential transfer operations over integer relations.
#derive(@debug.Debug)
pub(all) enum Transfer {
  Guard(Array[Constraint])
  Assign(Int32, Term, Int64)
  Set(Int32, Int64)
  Forget(Int32)
}

///|
#derive(@debug.Debug, ToJson)
pub enum LoopStatus {
  Inductive
  BudgetExhausted
}

///|
pub struct LoopResult {
  head : Octagon
  status : LoopStatus
  iterations : Int32
}

///|
pub fn LoopResult::invariant(self : LoopResult) -> Octagon {
  self.head
}

///|
pub fn LoopResult::status(self : LoopResult) -> LoopStatus {
  self.status
}

///|
pub fn LoopResult::iterations(self : LoopResult) -> Int32 {
  self.iterations
}

///|
pub fn Octagon::execute(
  self : Octagon,
  operations : Array[Transfer],
) -> Octagon raise OctagonError {
  if operations.length() > 128 {
    raise Limit("at most 128 transfer operations, got \{operations.length()}")
  }
  let mut s = self
  for op in operations {
    s = match op {
      Guard(cs) => s.refine(cs)
      Assign(x, term, delta) => s.assign(x, term, delta)
      Set(x, v) => s.set_constant(x, v)
      Forget(x) => s.forget(x)
    }
  }
  s
}

///|
/// Analyze a single while-loop with deterministic widening and bounded narrowing.
/// BudgetExhausted states are partial iterates, never certified invariants.
pub fn analyze_loop(
  entry : Octagon,
  conditions : Array[Constraint],
  body : Array[Transfer],
  max_iterations~ : Int32 = 64,
  widen_after~ : Int32 = 2,
  narrowing_steps~ : Int32 = 2,
) -> LoopResult raise OctagonError {
  if max_iterations < 1 ||
    max_iterations > 256 ||
    widen_after < 0 ||
    widen_after > 32 ||
    narrowing_steps < 0 ||
    narrowing_steps > 8 {
    raise Limit("loop budget: iterations 1..256, delay 0..32, narrowing 0..8")
  }
  // Validate transfers even for unreachable input.
  ignore(entry.refine(conditions).execute(body))
  let mut head = entry.canonical()
  for iteration in 0..<max_iterations {
    let next = entry.join(head.refine(conditions).execute(body))
    if next.subset_of(head) {
      for _ in 0..<narrowing_steps {
        head = head.meet(entry.join(head.refine(conditions).execute(body)))
      }
      if !verify_invariant(entry, head, conditions, body) {
        raise Arithmetic("post-fixpoint validation failed")
      }
      return {
        head: head.canonical(),
        status: Inductive,
        iterations: iteration + 1,
      }
    }
    head = if iteration < widen_after {
      head.join(next)
    } else {
      head.widen(next)
    }
  }
  {
    head: head.canonical(),
    status: BudgetExhausted,
    iterations: max_iterations,
  }
}

///|
/// Re-check initialization and preservation, independently of iteration status.
pub fn verify_invariant(
  entry : Octagon,
  candidate : Octagon,
  conditions : Array[Constraint],
  body : Array[Transfer],
) -> Bool raise OctagonError {
  entry.subset_of(candidate) &&
  candidate.refine(conditions).execute(body).subset_of(candidate)
}
