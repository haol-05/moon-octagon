///|
test "integer parity rejects a rationally feasible point" {
  // x+y=1 and x-y=0 requires x=y=1/2 over reals, impossible over integers.
  let s = from_constraints(2, [
    relation(positive(0), positive(1), 1L),
    relation(negative(0), negative(1), -1L),
    relation(positive(0), negative(1), 0L),
    relation(negative(0), positive(1), 0L),
  ])
  assert_true(s.is_bottom())
}

///|
test "integer strengthening and negative floor" {
  let s = from_constraints(2, [
    relation(positive(0), positive(0), -3L),
    lower(1, 5L),
  ])
  assert_eq(s.interval(0), Some({ lower: None, upper: Some(-2L), }))
  assert_eq(s.bound(positive(0), Some(negative(1))), Some(-7L))
}

///|
test "retains sum relation absent from independent intervals" {
  let s = from_constraints(2, [
    lower(0, 0L),
    lower(1, 0L),
    relation(positive(0), positive(1), 100L),
  ])
  assert_eq(s.interval(0), Some({ lower: Some(0L), upper: Some(100L), }))
  assert_true(s.entails(relation(positive(0), positive(1), 100L)))
  assert_false(s.contains([100L, 100L]))
  match s.check(upper(0, 50L)) {
    Refuted(v) => {
      assert_true(s.contains(v))
      assert_false(satisfies(v, upper(0, 50L)))
    }
    _ => fail("expected checked countermodel")
  }
}

///|
test "same-variable cancellation and diagonal inconsistency" {
  assert_true(
    from_constraints(1, [relation(positive(0), negative(0), -1L)]).is_bottom(),
  )
  assert_true(
    from_constraints(1, [relation(positive(0), negative(0), 0L)]).is_top(),
  )
}

///|
test "projection preserves a transitive relationship" {
  let s = from_constraints(3, [
    relation(positive(0), negative(1), 2L),
    relation(positive(1), negative(2), 3L),
  ])
  let t = s.forget(1)
  assert_true(t.entails(relation(positive(0), negative(2), 5L)))
  assert_eq(t.interval(1), Some({ lower: None, upper: None, }))
}

///|
test "signed self assignment uses old value and preserves source" {
  let s = from_constraints(2, [
    lower(0, 2L),
    upper(0, 5L),
    relation(positive(0), negative(1), 0L),
    relation(negative(0), positive(1), 0L),
  ])
  let t = s.assign(0, negative(0), 7L)
  assert_eq(t.bound(positive(0), Some(positive(1))), Some(7L))
  assert_eq(t.bound(negative(0), Some(negative(1))), Some(-7L))
  assert_true(s.contains([2L, 2L]))
  assert_true(t.contains([5L, 2L]))
  assert_false(t.contains([2L, 2L]))
}

///|
test "copy assignment overwrites old target constraints" {
  let s = from_constraints(2, [
    lower(0, 100L),
    upper(0, 100L),
    lower(1, 2L),
    upper(1, 4L),
  ])
  let t = s.assign(0, positive(1), 3L)
  assert_eq(t.interval(0), Some({ lower: Some(5L), upper: Some(7L), }))
  assert_true(t.entails(relation(positive(0), negative(1), 3L)))
  assert_eq(s.interval(0), Some({ lower: Some(100L), upper: Some(100L), }))
}

///|
test "join is an abstraction and meet exact intersection" {
  let a = top(2).set_constant(0, 0L).set_constant(1, 0L)
  let b = top(2).set_constant(0, 2L).set_constant(1, 2L)
  let j = a.join(b)
  assert_true(a.subset_of(j))
  assert_true(b.subset_of(j))
  assert_true(j.contains([1L, 1L]))
  assert_false(j.contains([1L, 0L]))
  assert_true(a.meet(b).is_bottom())
  assert_true(j.meet(a).equivalent(a))
}

///|
test "widening raw sequence stabilizes and queries do not mutate" {
  let start = top(2).set_constant(0, 0L).set_constant(1, 0L)
  let next = start.join(
    start.assign(0, positive(0), 1L).assign(1, positive(1), 1L),
  )
  let w = start.widen(next)
  assert_eq(w.interval(0), Some({ lower: Some(0L), upper: None, }))
  assert_true(w.entails(relation(positive(0), negative(1), 0L)))
  assert_true(
    w
    .widen(w.assign(0, positive(0), 1L).assign(1, positive(1), 1L))
    .equivalent(w),
  )
}

///|
test "inductive loop invariant and narrowing" {
  let entry = top(2).set_constant(0, 0L).set_constant(1, 10L)
  let conditions = [upper(0, 9L)]
  let body = [Assign(0, positive(0), 1L), Assign(1, positive(1), -1L)]
  let result = analyze_loop(entry, conditions, body)
  match result.status() {
    Inductive => ()
    _ => fail("expected convergence")
  }
  let head = result.invariant()
  assert_true(verify_invariant(entry, head, conditions, body))
  assert_true(head.entails(relation(positive(0), positive(1), 10L)))
  assert_true(head.entails(relation(negative(0), negative(1), -10L)))
  assert_eq(head.interval(0), Some({ lower: Some(0L), upper: Some(10L), }))
  let exit = head.refine([lower(0, 10L)])
  assert_eq(exit.interval(1), Some({ lower: Some(0L), upper: Some(0L), }))
}

///|
test "budget exhaustion never labels a partial state inductive" {
  let entry = top(1).set_constant(0, 0L)
  let r = analyze_loop(
    entry,
    [],
    [Assign(0, positive(0), 1L)],
    max_iterations=1,
    widen_after=32,
  )
  match r.status() {
    BudgetExhausted => ()
    _ => fail("expected budget exhaustion")
  }
  assert_false(
    verify_invariant(entry, r.invariant(), [], [Assign(0, positive(0), 1L)]),
  )
}

///|
test "minimal conflict retains original indices and detects tampering" {
  let cs = [upper(0, 5L), lower(0, 6L), upper(1, 100L), upper(0, 50L)]
  let c = match explain_conflict(2, cs) {
    Some(c) => c
    None => fail("missing conflict")
  }
  assert_eq(c.indices, [0, 1])
  assert_true(verify_conflict(2, cs, c))
  assert_false(verify_conflict(2, cs, { indices: [0, 0, 1], checks: 0, }))
  assert_false(verify_conflict(2, cs, { indices: [0, 1, 2], checks: 0, }))
  assert_eq(explain_conflict(2, [upper(0, 5L)]), None)
}

///|
test "witnesses for unbounded and lower bounded spaces" {
  assert_eq(top(3).witness(), Some([0L, 0L, 0L]))
  let s = from_constraints(3, [
    lower(0, 3L),
    relation(positive(0), negative(1), -2L),
    relation(positive(1), positive(2), -10L),
  ])
  let v = match s.witness() {
    Some(v) => v
    None => fail("missing witness")
  }
  assert_true(s.contains(v))
  assert_eq(bottom(1).witness(), None)
  match bottom(1).check(upper(0, -5L)) {
    Vacuous => ()
    _ => fail("expected vacuity")
  }
}

///|
test "validation applies even to bottom" {
  let invalid = { left: { variable: 0, sign: 0, }, right: None, bound: 0L, }
  let got = try {
    ignore(bottom(1).refine([invalid]))
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(got)
  let mismatch = try {
    ignore(top(1).join(top(2)))
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(mismatch)
  let limit = try {
    ignore(top(25))
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(limit)
}

///|
test "defensive ownership of input and witness arrays" {
  let cs = [upper(0, 1L)]
  let s = from_constraints(1, cs)
  cs[0] = upper(0, 100L)
  assert_eq(s.interval(0), Some({ lower: None, upper: Some(1L), }))
  let v = match s.witness() {
    Some(v) => v
    None => fail("missing witness")
  }
  v[0] = 200L
  assert_false(s.contains(v))
  assert_true(s.entails(upper(0, 1L)))
}

///|
test "strict JSON success conflict errors and budgets" {
  let success = process_json(
    "{\"op\":\"analyze\",\"dimensions\":1,\"constraints\":[]}",
  )
  assert_true(success.contains("\"ok\":true"))
  for
    input in [
      "{\"op\":\"analyze\",\"dimensions\":1,\"constraints\":[],\"unexpected\":true}",
      "{\"op\":\"analyze\",\"dimensions\":1,\"constraints\":[],\"dimensions\":2}",
      "{\"op\":\"analyze\",\"dimensions\":1.5,\"constraints\":[]}", "{\"op\":\"analyze\",\"dimensions\":1,\"constraints\":[],\"transfers\":[]}",
      "{\"op\":\"loop\",\"dimensions\":1,\"constraints\":[],\"guard\":[],\"body\":[],\"max_iterations\":0}",
      "{not json}",
    ] {
    assert_true(process_json(input).contains("\"ok\":false"))
  }
}
