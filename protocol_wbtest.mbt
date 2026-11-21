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

///|
test "text and box protocol operations" {
  let parsed = process_json(
    "{\"op\":\"text\",\"dimensions\":2,\"text\":\"x0 in [0, 10]\\nx0 + x1 <= 12\"}",
  )
  assert_true(parsed.contains("\"ok\":true"))
  assert_true(parsed.contains("x0+x1<=12"))
  let boxed = process_json(
    "{\"op\":\"box\",\"dimensions\":2,\"constraints\":[{\"left\":{\"variable\":0,\"sign\":1},\"bound\":5},{\"left\":{\"variable\":0,\"sign\":-1},\"bound\":0}]}",
  )
  assert_true(boxed.contains("\"ok\":true"))
  assert_true(boxed.contains("x0 in [0, 5]"))
  assert_true(
    process_json("{\"op\":\"text\",\"dimensions\":1,\"text\":\"x0 in [5, 2]\"}").contains(
      "\"ok\":false",
    ),
  )
  assert_true(
    process_json(
      "{\"op\":\"box\",\"dimensions\":1,\"constraints\":[],\"text\":\"x0 <= 1\"}",
    ).contains("\"ok\":false"),
  )
}

///|
test "cfg protocol operation reports states and rejects bad edges" {
  let input = "{\"op\":\"cfg\",\"dimensions\":1,\"constraints\":[{\"left\":{\"variable\":0,\"sign\":-1},\"bound\":0},{\"left\":{\"variable\":0,\"sign\":1},\"bound\":10}],\"blocks\":[{\"conditions\":[],\"body\":[],\"successors\":[1,2]},{\"conditions\":[{\"left\":{\"variable\":0,\"sign\":1},\"bound\":5}],\"body\":[{\"op\":\"assign\",\"target\":0,\"source\":{\"variable\":0,\"sign\":1},\"offset\":1}],\"successors\":[3]},{\"conditions\":[{\"left\":{\"variable\":0,\"sign\":-1},\"bound\":-6}],\"body\":[{\"op\":\"assign\",\"target\":0,\"source\":{\"variable\":0,\"sign\":1},\"offset\":-1}],\"successors\":[3]},{\"conditions\":[],\"body\":[],\"successors\":[]}]}"
  let out = process_json(input)
  assert_true(out.contains("\"ok\":true"))
  assert_true(out.contains("\"status\":\"stable\""))
  assert_true(out.contains("\"states\":"))
  let bad = process_json(
    "{\"op\":\"cfg\",\"dimensions\":1,\"constraints\":[],\"blocks\":[{\"conditions\":[],\"body\":[],\"successors\":[5]}]}",
  )
  assert_true(bad.contains("\"ok\":false"))
}
