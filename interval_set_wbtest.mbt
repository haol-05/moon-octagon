///|
test "box top bottom intervals and rendering" {
  let t = box_top(2)
  assert_true(t.is_top())
  assert_eq(t.interval(0), Some({ lower: None, upper: None, }))
  assert_eq(t.render(), "top(2)")
  let b = box_bottom(2)
  assert_true(b.is_bottom())
  assert_eq(b.interval(0), None)
  assert_eq(b.render(), "bottom(2)")
  let s = from_constraints(1, [lower(0, 0L), upper(0, 5L)]).to_box()
  assert_eq(s.render(), "x0 in [0, 5]")
}

///|
test "box meet and join agree with concrete intersection and hull" {
  let a = from_constraints(2, [
    lower(0, 0L),
    upper(0, 5L),
    lower(1, 0L),
    upper(1, 5L),
  ]).to_box()
  let b = from_constraints(2, [
    lower(0, 3L),
    upper(0, 8L),
    lower(1, -2L),
    upper(1, 2L),
  ]).to_box()
  let m = a.meet(b)
  let j = a.join(b)
  for x in -3..<9 {
    for y in -3..<6 {
      let p = [x.to_int64(), y.to_int64()]
      assert_eq(m.contains(p), a.contains(p) && b.contains(p))
      assert_eq(j.contains(p), x >= 0 && x <= 8 && y >= -2 && y <= 5)
    }
  }
  assert_eq(m.interval(0), Some({ lower: Some(3L), upper: Some(5L), }))
  assert_eq(m.interval(1), Some({ lower: Some(0L), upper: Some(2L), }))
  assert_eq(j.interval(0), Some({ lower: Some(0L), upper: Some(8L), }))
  assert_eq(j.interval(1), Some({ lower: Some(-2L), upper: Some(5L), }))
  assert_true(m.subset_of(a))
  assert_true(a.subset_of(j))
}

///|
test "box assignment and entailment follow interval arithmetic" {
  let a = from_constraints(1, [lower(0, -2L), upper(0, 3L)]).to_box()
  let r = a.assign(0, negative(0), 1L)
  assert_eq(r.interval(0), Some({ lower: Some(-2L), upper: Some(3L), }))
  let shifted = a.assign(0, positive(0), 2L)
  assert_eq(shifted.interval(0), Some({ lower: Some(0L), upper: Some(5L), }))
  let bounded = from_constraints(2, [
    lower(0, 0L),
    upper(0, 10L),
    lower(1, 0L),
    upper(1, 10L),
  ]).to_box()
  assert_true(bounded.entails(relation(positive(0), positive(1), 20L)))
  assert_false(bounded.entails(relation(positive(0), positive(1), 19L)))
  assert_true(bounded.entails(lower(0, 0L)))
  assert_false(bounded.entails(lower(0, 1L)))
  assert_true(box_bottom(2).entails(upper(0, -100L)))
}

///|
test "box and octagon conversions lose exactly the relations" {
  let o = from_constraints(2, [
    lower(0, 0L),
    lower(1, 0L),
    upper(0, 100L),
    upper(1, 100L),
    relation(positive(0), positive(1), 100L),
  ])
  let b = o.to_box()
  assert_eq(b.interval(0), Some({ lower: Some(0L), upper: Some(100L), }))
  assert_true(o.subset_of(b.to_octagon()))
  assert_true(b.to_octagon().to_box().equivalent(b))
  let empty = bottom(2).to_box()
  assert_true(empty.is_bottom())
  assert_true(empty.to_octagon().is_bottom())
}

///|
test "box widening and validation" {
  let a = from_constraints(1, [lower(0, 0L), upper(0, 5L)]).to_box()
  let b = from_constraints(1, [lower(0, 0L), upper(0, 6L)]).to_box()
  assert_eq(a.widen(b).interval(0), Some({ lower: Some(0L), upper: None, }))
  assert_true(a.widen(a).equivalent(a))
  let mismatch = try {
    ignore(a.join(box_top(2)))
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(mismatch)
  let index = try {
    ignore(a.interval(1))
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(index)
}

///|
test "box text round-trip and aggregate folds" {
  let a = from_constraints(2, [
    lower(0, 0L),
    upper(0, 5L),
    lower(1, -2L),
    upper(1, 2L),
  ]).to_box()
  let b = from_constraints(2, [
    lower(0, 3L),
    upper(0, 8L),
    lower(1, 0L),
    upper(1, 4L),
  ]).to_box()
  let text = a.to_text()
  let again = from_constraints(2, parse_constraints(2, text)).to_box()
  assert_true(again.equivalent(a))
  let joined = box_join_all([a, b])
  assert_true(a.subset_of(joined))
  assert_true(b.subset_of(joined))
  assert_eq(joined.interval(0), Some({ lower: Some(0L), upper: Some(8L), }))
  let met = box_meet_all([a, b])
  assert_eq(met.interval(0), Some({ lower: Some(3L), upper: Some(5L), }))
  let none : Array[Box] = []
  let join_error = try {
    ignore(box_join_all(none))
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(join_error)
  let meet_error = try {
    ignore(box_meet_all(none))
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(meet_error)
  let empty_text = try {
    ignore(box_bottom(1).to_text())
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(empty_text)
}

///|
test "box witness respects every bound" {
  let b = from_constraints(2, [
    lower(0, 2L),
    upper(0, 5L),
    lower(1, -4L),
    upper(1, -1L),
  ]).to_box()
  let w = match b.witness() {
    Some(w) => w
    None => fail("expected a box witness")
  }
  assert_true(b.contains(w))
  assert_eq(box_bottom(1).witness(), None)
  let unbounded = box_top(3).witness()
  assert_eq(unbounded, Some([0L, 0L, 0L]))
}

///|
test "box empty states and mutation helpers stay total" {
  let e = box_bottom(2)
  assert_true(e.meet(box_top(2)).is_bottom())
  assert_true(e.join(box_top(2)).is_top())
  assert_true(e.widen(box_top(2)).is_top())
  assert_true(box_top(2).widen(e).is_top())
  assert_true(e.subset_of(box_top(2)))
  assert_false(box_top(2).subset_of(e))
  assert_true(e.entails(upper(0, -5L)))
  assert_true(e.assign(0, positive(0), 1L).is_bottom())
  assert_true(e.forget(0).is_bottom())
  assert_true(e.set_constant(0, 1L).is_bottom())
  assert_eq(e.witness(), None)
  assert_false(e.contains([0L, 0L]))
  let with_constant = box_top(2).set_constant(1, 7L)
  assert_eq(
    with_constant.interval(1),
    Some({ lower: Some(7L), upper: Some(7L), }),
  )
  assert_eq(
    with_constant.forget(1).interval(1),
    Some({ lower: None, upper: None, }),
  )
  let mismatch = try {
    ignore(box_top(1).contains([0L, 1L]))
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(mismatch)
  assert_false(box_top(1).entails(upper(0, 0L)))
}

///|
test "box subset respects one-sided bounds and disjoint meet" {
  let point = box_top(1).set_constant(0, 5L)
  let wide = from_constraints(1, [lower(0, 0L)]).to_box()
  assert_true(point.subset_of(wide))
  assert_false(wide.subset_of(point))
  let left = from_constraints(1, [lower(0, 0L), upper(0, 1L)]).to_box()
  let right = from_constraints(1, [lower(0, 2L), upper(0, 3L)]).to_box()
  assert_true(left.meet(right).is_bottom())
  assert_eq(
    left.join(right).interval(0),
    Some({ lower: Some(0L), upper: Some(3L), }),
  )
}

///|
test "box text handles one-sided bounds" {
  let lower_only = from_constraints(1, [lower(0, 0L)]).to_box()
  assert_eq(lower_only.to_text(), "x0 >= 0")
  let upper_only = from_constraints(1, [upper(0, 5L)]).to_box()
  assert_eq(upper_only.to_text(), "x0 <= 5")
  assert_eq(box_top(1).to_text(), "")
  assert_eq(
    from_constraints(1, parse_constraints(1, lower_only.to_text()))
    .to_box()
    .render(),
    "x0 in [0, inf)",
  )
}
