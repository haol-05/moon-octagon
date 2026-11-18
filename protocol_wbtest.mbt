///|
test "conflict JSON explains the selected constraints" {
  let input = "{\"op\":\"conflict\",\"dimensions\":1,\"constraints\":[{\"left\":{\"variable\":0,\"sign\":1},\"bound\":5},{\"left\":{\"variable\":0,\"sign\":-1},\"bound\":-6}]}"
  let out = process_json(input)
  assert_true(out.contains("\"ok\":true"))
  assert_true(out.contains("\"verified\":true"))
  assert_true(out.contains("x0 <= 5"))
  assert_true(out.contains("-x0 <= -6"))
  assert_eq(
    render_constraint(relation(positive(0), negative(1), 2L)),
    "x0 - x1 <= 2",
  )
  assert_eq(render_constraint(lower(0, 5L)), "-x0 <= -5")
}
