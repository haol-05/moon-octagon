///|
test "box overapproximates concrete points and text round-trips" {
  let state : Array[Int64] = [20261121L]
  for _ in 0..<60 {
    let cs = [
      lower(0, -3L),
      upper(0, 3L),
      lower(1, -3L),
      upper(1, 3L),
      relation(positive(0), positive(1), next_rand(state) % 9L - 4L),
      relation(positive(0), negative(1), next_rand(state) % 9L - 4L),
    ]
    let points = concrete_points(cs)
    let s = from_constraints(2, cs)
    let b = s.to_box()
    for p in points {
      assert_true(b.contains(p))
    }
    if s.is_bottom() {
      continue
    }
    let round = from_constraints(2, parse_constraints(2, s.to_text()))
    assert_true(round.equivalent(s))
    for
      c in [
        upper(0, 0L),
        lower(1, 0L),
        relation(positive(0), positive(1), 0L),
        relation(negative(0), positive(1), 1L),
      ] {
      if b.entails(c) {
        for p in points {
          assert_true(expr_value(p, c) <= c.bound)
        }
      }
    }
  }
}
