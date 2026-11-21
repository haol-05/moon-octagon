///|
test "simultaneous assignment swaps without sequential interference" {
  let s = from_constraints(2, [
    lower(0, 1L),
    upper(0, 1L),
    lower(1, 2L),
    upper(1, 2L),
  ])
  let t = s.assign_parallel([
    { target: 0, source: positive(1), offset: 0L, },
    { target: 1, source: positive(0), offset: 0L, },
  ])
  assert_eq(t.interval(0), Some({ lower: Some(2L), upper: Some(2L), }))
  assert_eq(t.interval(1), Some({ lower: Some(1L), upper: Some(1L), }))
  let sequential = s.assign(0, positive(1), 0L).assign(1, positive(0), 0L)
  assert_true(!t.equivalent(sequential))
}

///|
test "simultaneous assignment image matches concrete mapping" {
  let box = from_constraints(2, [
    lower(0, 0L),
    upper(0, 2L),
    lower(1, 0L),
    upper(1, 2L),
  ])
  let t = box.assign_parallel([
    { target: 0, source: positive(1), offset: 1L, },
    { target: 1, source: negative(0), offset: 2L, },
  ])
  for x in -3..<6 {
    for y in -3..<6 {
      let p = [x.to_int64(), y.to_int64()]
      assert_eq(t.contains(p), x >= 1 && x <= 3 && y >= 0 && y <= 2)
    }
  }
}

///|
test "simultaneous assignment validation and empty states" {
  let s = top(2)
  let duplicate = try {
    ignore(
      s.assign_parallel([
        { target: 0, source: positive(0), offset: 0L, },
        { target: 0, source: positive(1), offset: 0L, },
      ]),
    )
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(duplicate)
  let too_many = try {
    let assignments : Array[Assignment] = Array::makei(9, i => {
      target: 0,
      source: positive(0),
      offset: i.to_int64(),
    })
    ignore(s.assign_parallel(assignments))
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(too_many)
  let none : Array[Assignment] = []
  assert_true(s.assign_parallel(none).equivalent(s))
  assert_true(bottom(2).assign_parallel(none).is_bottom())
}

///|
test "renaming is a simultaneous bijection" {
  let s = from_constraints(2, [
    lower(0, 1L),
    upper(0, 1L),
    lower(1, 2L),
    upper(1, 2L),
  ])
  let r = s.rename([1, 0])
  assert_eq(r.interval(0), Some({ lower: Some(2L), upper: Some(2L), }))
  assert_eq(r.interval(1), Some({ lower: Some(1L), upper: Some(1L), }))
  let repeated = try {
    ignore(s.rename([0, 0]))
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(repeated)
  let wrong_length = try {
    ignore(s.rename([0]))
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(wrong_length)
}

///|
test "join_all and meet_all fold compatible states" {
  let a = top(2).set_constant(0, 0L).set_constant(1, 0L)
  let b = top(2).set_constant(0, 2L).set_constant(1, 2L)
  let c = top(2).set_constant(0, 1L).set_constant(1, 1L)
  let j = join_all([a, b, c])
  assert_true(a.subset_of(j))
  assert_true(c.subset_of(j))
  assert_true(j.contains([1L, 1L]))
  assert_true(meet_all([a, b]).is_bottom())
  let none : Array[Octagon] = []
  let join_error = try {
    ignore(join_all(none))
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(join_error)
  let meet_error = try {
    ignore(meet_all(none))
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(meet_error)
}

///|
test "parallel limits and empty inputs" {
  let wide = top(24)
  let limit = try {
    ignore(
      wide.assign_parallel([{ target: 0, source: positive(1), offset: 0L, }]),
    )
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(limit)
  let empty = bottom(2)
  assert_true(
    empty
    .assign_parallel([{ target: 0, source: positive(1), offset: 0L, }])
    .is_bottom(),
  )
  assert_true(empty.rename([1, 0]).is_bottom())
  let empty_names : Array[Assignment] = []
  assert_true(empty.assign_parallel(empty_names).is_bottom())
}
