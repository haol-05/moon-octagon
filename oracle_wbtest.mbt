///|
/// Direct concrete semantics; this oracle never reads a DBM.
fn concrete_holds(p : Array[Int64], cs : Array[Constraint]) -> Bool {
  for c in cs {
    let a = p[c.left.variable] * c.left.sign.to_int64()
    let b = match c.right {
      None => 0L
      Some(t) => p[t.variable] * t.sign.to_int64()
    }
    if a + b > c.bound {
      return false
    }
  }
  true
}

///|
fn concrete_points(cs : Array[Constraint]) -> Array[Array[Int64]] {
  let result : Array[Array[Int64]] = []
  for x in -3..<4 {
    for y in -3..<4 {
      let p = [x.to_int64(), y.to_int64()]
      if concrete_holds(p, cs) {
        result.push(p)
      }
    }
  }
  result
}

///|
test "independent exhaustive membership signed assignment projection and export" {
  for a in [-1, 1] {
    for b in [-1, 1] {
      for c in -4..<5 {
        let cs = [
          lower(0, -3L),
          upper(0, 3L),
          lower(1, -3L),
          upper(1, 3L),
          relation(
            { variable: 0, sign: a, },
            { variable: 1, sign: b, },
            c.to_int64(),
          ),
        ]
        let points = concrete_points(cs)
        let s = from_constraints(2, cs)
        for x in -3..<4 {
          for y in -3..<4 {
            let p = [x.to_int64(), y.to_int64()]
            assert_eq(s.contains(p), concrete_holds(p, cs))
          }
        }
        assert_false(s.is_bottom())
        assert_true(from_constraints(2, s.constraints()).equivalent(s))
        let forgotten = s.forget(0)
        for y in -3..<4 {
          let expected = points.any(p => p[1] == y.to_int64())
          assert_eq(forgotten.contains([100L, y.to_int64()]), expected)
        }
        for target in 0..<2 {
          for source in 0..<2 {
            for sign in [-1, 1] {
              let t = s.assign(target, { variable: source, sign, }, 1L)
              for x in -4..<5 {
                for y in -4..<5 {
                  let post = [x.to_int64(), y.to_int64()]
                  let expected = points.any(p => {
                    let image = p.copy()
                    image[target] = p[source] * sign.to_int64() + 1L
                    image == post
                  })
                  assert_eq(t.contains(post), expected)
                }
              }
            }
          }
        }
      }
    }
  }
}

///|
test "multi-variable projection agrees with concrete projection" {
  let cs = [
    lower(0, -3L),
    upper(0, 3L),
    lower(1, -3L),
    upper(1, 3L),
    lower(2, -3L),
    upper(2, 3L),
    relation(positive(0), positive(1), 2L),
    relation(negative(1), positive(2), 1L),
  ]
  let points : Array[Array[Int64]] = []
  for x in -3..<4 {
    for y in -3..<4 {
      for z in -3..<4 {
        let p = [x.to_int64(), y.to_int64(), z.to_int64()]
        if concrete_holds(p, cs) {
          points.push(p)
        }
      }
    }
  }
  assert_true(points.length() > 0)
  let s = from_constraints(3, cs)
  let t = s.forget_many([0, 2])
  assert_eq(t.interval(0), Some({ lower: None, upper: None, }))
  assert_eq(t.interval(2), Some({ lower: None, upper: None, }))
  let mut lo = 100L
  let mut hi = -100L
  for p in points {
    if p[1] < lo {
      lo = p[1]
    }
    if p[1] > hi {
      hi = p[1]
    }
  }
  assert_eq(t.interval(1), Some({ lower: Some(lo), upper: Some(hi), }))
  for y in -3..<4 {
    let expected = points.any(p => p[1] == y.to_int64())
    assert_eq(t.contains([99L, y.to_int64(), 99L]), expected)
    assert_eq(t.contains([-99L, y.to_int64(), -99L]), expected)
  }
}

///|
test "tight closure canonical structural invariants" {
  let cs = [
    lower(0, -2L),
    upper(0, 3L),
    relation(positive(0), positive(1), 5L),
    relation(negative(0), positive(1), 2L),
  ]
  let s = from_constraints(2, cs)
  assert_true(s.canonical().equivalent(s))
  let m = s.matrix
  for i in 0..<m.length() {
    assert_eq(m[i][i], 0L)
    if m[i][complement(i)] != INF {
      assert_eq(m[i][complement(i)] % 2L, 0L)
    }
    for j in 0..<m.length() {
      assert_eq(m[i][j], m[complement(j)][complement(i)])
      for k in 0..<m.length() {
        assert_true(m[i][j] <= plus(m[i][k], m[k][j]))
      }
    }
  }
}

///|
test "resource errors and large derived-bound roundtrip" {
  let large = from_constraints(2, [
    upper(0, 1000000000L),
    relation(positive(1), negative(0), 1000000000L),
  ])
  assert_eq(large.interval(1), Some({ lower: None, upper: Some(2000000000L), }))
  assert_true(from_constraints(2, large.constraints()).equivalent(large))
  let limit = try {
    ignore(explain_conflict(1, [lower(0, 1L), upper(0, 0L)], max_checks=1))
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(limit)
  let arithmetic = try {
    ignore(
      from_constraints(1, [
        upper(0, -500000000000000L),
        lower(0, 500000000000000L),
      ]),
    )
    false
  } catch {
    Arithmetic(_) => true
    _ => false
  }
  assert_true(arithmetic)
}

///|
test "JSON literal precision nesting batch limits and item isolation" {
  for literal in ["1.0", "1e0", "1.00000000000000000000001"] {
    let input = "{\"op\":\"analyze\",\"dimensions\":\{literal},\"constraints\":[]}"
    assert_true(process_json(input).contains("\"ok\":false"))
    assert_true(process_batch_json("[\{input}]").contains("\"ok\":false"))
  }
  let batch = process_batch_json(
    "[{\"op\":\"analyze\",\"dimensions\":1,\"constraints\":[]},{\"op\":\"missing\",\"dimensions\":1,\"constraints\":[]}]",
  )
  assert_true(batch.contains("\"ok\":true"))
  assert_true(batch.contains("\"ok\":false"))
  assert_true(process_batch_json("{}").contains("\"ok\":false"))
  assert_eq(process_batch_json("[]"), "[]")
  let nested = String::make(40, '[') + "0" + String::make(40, ']')
  assert_true(process_json(nested).contains("\"code\":\"json\""))
}
