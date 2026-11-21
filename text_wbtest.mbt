///|
test "text parses intervals relations and comments" {
  let input = "# shared budget\nx0 in [0, 100]\nx1 >= 0\nx1 <= 80\nx0 + x1 <= 100\nx0 - x1 <= 20\n-x0 + x1 <= 10"
  let cs = parse_constraints(2, input)
  assert_eq(cs.length(), 7)
  let s = from_constraints(2, cs)
  assert_true(s.entails(relation(positive(0), positive(1), 100L)))
  assert_true(s.entails(relation(positive(0), negative(1), 20L)))
  assert_true(s.entails(relation(negative(0), positive(1), 10L)))
  assert_true(s.entails(upper(1, 80L)))
  assert_true(s.entails(lower(0, 0L)))
}

///|
test "text accepts negative literals and semicolon separators" {
  let cs = parse_constraints(2, "x0 in [-5, -2]; x1 >= -3; x0+x1<=0")
  assert_eq(cs.length(), 4)
  let s = from_constraints(2, cs)
  assert_eq(s.interval(0), Some({ lower: Some(-5L), upper: Some(-2L), }))
  assert_true(s.entails(lower(1, -3L)))
}

///|
test "text round-trips canonical and relation-only domains" {
  let s = from_constraints(2, [
    lower(0, 0L),
    upper(0, 100L),
    lower(1, 0L),
    upper(1, 100L),
    relation(positive(0), positive(1), 100L),
    relation(positive(0), negative(1), 20L),
  ])
  let text = s.to_text()
  assert_true(text.length() > 0)
  let t = from_constraints(2, parse_constraints(2, text))
  assert_true(t.equivalent(s))
  let relation_only = top(2).refine([
    relation(positive(0), positive(1), 5L),
    relation(negative(0), positive(1), 2L),
  ])
  let again = from_constraints(2, parse_constraints(2, relation_only.to_text()))
  assert_true(again.equivalent(relation_only))
  assert_eq(top(2).to_text(), "")
  assert_true(
    from_constraints(2, parse_constraints(2, top(2).to_text())).is_top(),
  )
}

///|
test "text rejects malformed out-of-range and oversized statements" {
  let cases = [
    "x0 in [5, 2]", "x1 <= 0", "x0 < 5", "x0 <= 5 extra", "y0 <= 1", "x0 in [0 5]",
    "x0 + 3 <= 1",
  ]
  for input in cases {
    let failed = try {
      ignore(parse_constraints(1, input))
      false
    } catch {
      Invalid(_) => true
      _ => false
    }
    assert_true(failed)
  }
  let too_long = String::make(200001, 'x')
  let limited = try {
    ignore(parse_constraints(1, too_long))
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(limited)
  let bottom_text = try {
    ignore(bottom(1).to_text())
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(bottom_text)
}

///|
test "text equality expands to two inequalities" {
  let cs = parse_constraints(2, "x0 + x1 = 10")
  assert_eq(cs.length(), 2)
  let s = from_constraints(2, cs)
  assert_true(s.entails(relation(positive(0), positive(1), 10L)))
  assert_true(s.entails(relation(negative(0), negative(1), -10L)))
  assert_false(s.entails(relation(positive(0), positive(1), 9L)))
}

///|
test "text covers signs brackets and malformed boundaries" {
  let signed = parse_constraints(2, "+x0 - x1 <= 3")
  assert_eq(signed.length(), 1)
  let s = from_constraints(2, signed)
  assert_true(s.entails(relation(positive(0), negative(1), 3L)))
  let cases = [
    "x0 in 0", "x0 in [0, 1", "x0 in 0, 1]", "x0 5", "x0 + <= 1", "x <= 1", "x0|x1",
    "x0 >>> 1", "x0 <= 10000000000000000", "x9999999 <= 1",
  ]
  for input in cases {
    let failed = try {
      ignore(parse_constraints(2, input))
      false
    } catch {
      Invalid(_) => true
      Limit(_) => true
      _ => false
    }
    assert_true(failed)
  }
}
