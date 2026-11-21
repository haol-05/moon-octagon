///|
test "accessors empty-state operations and render edges" {
  assert_eq(top(2).size(), 2)
  assert_false(top(2).set_constant(0, 0L).is_top())
  assert_eq(from_constraints(1, [lower(0, 0L)]).render(), "x0 in [0, inf)")
  assert_eq(from_constraints(1, [upper(0, 5L)]).render(), "x0 in (-inf, 5]")
  assert_eq(
    render_constraint(relation(positive(0), positive(1), 5L)),
    "x0 + x1 <= 5",
  )
  let result = analyze_loop(
    top(1).set_constant(0, 0L),
    [],
    [Assign(0, positive(0), 1L)],
    max_iterations=2,
  )
  assert_true(result.iterations() >= 1)
}

///|
test "empty domain operations stay total" {
  assert_true(bottom(1).refine([upper(0, 0L)]).is_bottom())
  assert_true(bottom(1).canonical().is_bottom())
  assert_true(bottom(1).join(top(1)).is_top())
  assert_true(bottom(1).meet(top(1)).is_bottom())
  assert_true(top(1).join(bottom(1)).is_top())
  assert_true(bottom(1).subset_of(top(1)))
  assert_false(top(1).subset_of(bottom(1)))
  assert_true(bottom(1).widen(top(1)).is_top())
  assert_true(top(1).widen(bottom(1)).is_top())
  assert_true(bottom(1).assign(0, positive(0), 1L).is_bottom())
  assert_true(bottom(1).entails(upper(0, 0L)))
  assert_true(top(1).bound(positive(0), None) is None)
  assert_false(top(1).entails(upper(0, 0L)))
  let empty_bound = try {
    ignore(bottom(1).bound(positive(0), None))
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(empty_bound)
  let empty_export = try {
    ignore(bottom(1).constraints())
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(empty_export)
}

///|
test "resource limits and direct-vector validation" {
  let huge_offset = try {
    ignore(top(1).assign(0, positive(0), 1000000001L))
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(huge_offset)
  let huge_bound = try {
    ignore(from_constraints(1, [upper(0, 1000000000000001L)]))
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(huge_bound)
  let min_lower = try {
    ignore(from_constraints(1, [lower(0, -9223372036854775808L)]))
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(min_lower)
  let many : Array[Constraint] = Array::makei(4097, _ => upper(0, 0L))
  let too_many = try {
    ignore(top(1).refine(many))
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(too_many)
  let huge_value = try {
    ignore(satisfies([1000000000000001L], upper(0, 0L)))
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(huge_value)
  let wrong_length = try {
    ignore(top(2).contains([1L]))
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(wrong_length)
  let contains_limit = try {
    ignore(top(1).contains([1000000000000001L]))
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(contains_limit)
  let ops : Array[Transfer] = Array::makei(129, _ => Forget(0))
  let too_many_ops = try {
    ignore(top(1).execute(ops))
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(too_many_ops)
  let loop_limit = try {
    ignore(analyze_loop(top(1), [], [], max_iterations=0))
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(loop_limit)
}

///|
test "conflict verification rejects bad evidence and limits" {
  let many : Array[Constraint] = Array::makei(513, _ => upper(0, 0L))
  let explain_limit = try {
    ignore(explain_conflict(1, many))
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(explain_limit)
  let budget = try {
    ignore(explain_conflict(1, [lower(0, 1L), upper(0, 0L)], max_checks=0))
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(budget)
  let verify_limit = try {
    ignore(verify_conflict(1, many, { indices: [0], checks: 0, }))
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(verify_limit)
  let cs = [upper(0, 5L), lower(0, 6L)]
  assert_false(verify_conflict(1, cs, { indices: [], checks: 0, }))
  assert_false(verify_conflict(1, cs, { indices: [0], checks: 0, }))
}

///|
test "guard and set transfers execute in order" {
  let s = top(2).execute([
    Set(0, 5L),
    Set(1, 2L),
    Guard([relation(positive(0), positive(1), 7L)]),
  ])
  assert_eq(s.interval(0), Some({ lower: Some(5L), upper: Some(5L), }))
  assert_eq(s.interval(1), Some({ lower: Some(2L), upper: Some(2L), }))
}

///|
test "protocol operations expose transfer join meet loop and queries" {
  let transfer = process_json(
    "{\"op\":\"transfer\",\"dimensions\":2,\"constraints\":[],\"transfers\":[{\"op\":\"set\",\"target\":0,\"value\":3},{\"op\":\"assign\",\"target\":1,\"source\":{\"variable\":0,\"sign\":1},\"offset\":1},{\"op\":\"forget\",\"target\":0}]}",
  )
  assert_true(transfer.contains("\"ok\":true"))
  let joined = process_json(
    "{\"op\":\"join\",\"dimensions\":1,\"constraints\":[],\"other\":[{\"left\":{\"variable\":0,\"sign\":1},\"bound\":5}]}",
  )
  assert_true(joined.contains("\"ok\":true"))
  let met = process_json(
    "{\"op\":\"meet\",\"dimensions\":1,\"constraints\":[{\"left\":{\"variable\":0,\"sign\":1},\"bound\":5}],\"other\":[{\"left\":{\"variable\":0,\"sign\":1},\"bound\":3}]}",
  )
  assert_true(met.contains("\"ok\":true"))
  let looped = process_json(
    "{\"op\":\"loop\",\"dimensions\":1,\"constraints\":[{\"left\":{\"variable\":0,\"sign\":1},\"bound\":0},{\"left\":{\"variable\":0,\"sign\":-1},\"bound\":0}],\"guard\":[{\"left\":{\"variable\":0,\"sign\":1},\"bound\":9}],\"body\":[{\"op\":\"assign\",\"target\":0,\"source\":{\"variable\":0,\"sign\":1},\"offset\":1}]}",
  )
  assert_true(looped.contains("\"ok\":true"))
  let analyze = process_json(
    "{\"op\":\"analyze\",\"dimensions\":1,\"constraints\":[{\"left\":{\"variable\":0,\"sign\":1},\"bound\":5}],\"queries\":[{\"left\":{\"variable\":0,\"sign\":1},\"bound\":5},{\"left\":{\"variable\":0,\"sign\":1},\"bound\":4}]}",
  )
  assert_true(analyze.contains("proven"))
  assert_true(analyze.contains("refuted"))
  let empty = process_json(
    "{\"op\":\"analyze\",\"dimensions\":1,\"constraints\":[{\"left\":{\"variable\":0,\"sign\":1},\"bound\":0},{\"left\":{\"variable\":0,\"sign\":-1},\"bound\":-1}]}",
  )
  assert_true(empty.contains("\"state\":\"empty\""))
}

///|
test "protocol rejects malformed requests and oversized batches" {
  assert_true(process_json("[]").contains("\"ok\":false"))
  assert_true(process_json("{\"op\":\"analyze\"}").contains("\"ok\":false"))
  assert_true(
    process_json("{\"op\":1,\"dimensions\":1,\"constraints\":[]}").contains(
      "\"ok\":false",
    ),
  )
  assert_true(
    process_json("{\"op\":\"analyze\",\"dimensions\":1,\"constraints\":{}}").contains(
      "\"ok\":false",
    ),
  )
  assert_true(process_batch_json("1").contains("\"ok\":false"))
  let items : Array[String] = Array::makei(65, _ => {
    "{\"op\":\"analyze\",\"dimensions\":1,\"constraints\":[]}"
  })
  let sb = StringBuilder()
  for i in 0..<items.length() {
    if i > 0 {
      sb.write(",")
    }
    sb.write(items[i])
  }
  let batch = "[" + sb.to_string() + "]"
  assert_true(process_batch_json(batch).contains("\"code\":\"limit\""))
  let big = "[" + String::make(1000001, ' ') + "]"
  assert_true(process_batch_json(big).contains("\"code\":\"limit\""))
}

///|
test "protocol transfer and query edge cases" {
  let guarded = process_json(
    "{\"op\":\"transfer\",\"dimensions\":1,\"constraints\":[],\"transfers\":[{\"op\":\"guard\",\"constraints\":[{\"left\":{\"variable\":0,\"sign\":1},\"bound\":5}]}]}",
  )
  assert_true(guarded.contains("\"ok\":true"))
  assert_true(
    process_json(
      "{\"op\":\"transfer\",\"dimensions\":1,\"constraints\":[],\"transfers\":[{\"op\":\"bogus\"}]}",
    ).contains("\"ok\":false"),
  )
  assert_true(
    process_json(
      "{\"op\":\"transfer\",\"dimensions\":1,\"constraints\":[],\"transfers\":[5]}",
    ).contains("\"ok\":false"),
  )
  let binary = process_json(
    "{\"op\":\"analyze\",\"dimensions\":2,\"constraints\":[{\"left\":{\"variable\":0,\"sign\":1},\"right\":{\"variable\":1,\"sign\":-1},\"bound\":3}],\"queries\":[]}",
  )
  assert_true(binary.contains("\"ok\":true"))
  let vacuous = process_json(
    "{\"op\":\"analyze\",\"dimensions\":1,\"constraints\":[{\"left\":{\"variable\":0,\"sign\":1},\"bound\":0},{\"left\":{\"variable\":0,\"sign\":-1},\"bound\":-1}],\"queries\":[{\"left\":{\"variable\":0,\"sign\":1},\"bound\":0}]}",
  )
  assert_true(vacuous.contains("vacuous"))
  let satisfiable = process_json(
    "{\"op\":\"conflict\",\"dimensions\":1,\"constraints\":[{\"left\":{\"variable\":0,\"sign\":1},\"bound\":5}]}",
  )
  assert_true(satisfiable.contains("\"conflict\":null"))
  assert_true(satisfiable.contains("\"constraints\":[]"))
  let budget = process_json(
    "{\"op\":\"loop\",\"dimensions\":1,\"constraints\":[{\"left\":{\"variable\":0,\"sign\":1},\"bound\":0},{\"left\":{\"variable\":0,\"sign\":-1},\"bound\":0}],\"guard\":[],\"body\":[{\"op\":\"assign\",\"target\":0,\"source\":{\"variable\":0,\"sign\":1},\"offset\":1}],\"max_iterations\":1}",
  )
  assert_true(budget.contains("budget_exhausted"))
  assert_true(
    process_json(
      "{\"op\":\"analyze\",\"dimensions\":1,\"constraints\":[{\"left\":{\"variable\":0,\"sign\":1},\"bound\":10000000000}]}",
    ).contains("\"ok\":false"),
  )
  assert_true(
    process_json(
      "{\"op\":\"analyze\",\"dimensions\":1,\"constraints\":[{\"left\":{\"variable\":0,\"sign\":1},\"bound\":\"5\"}]}",
    ).contains("\"ok\":false"),
  )
  let many = StringBuilder()
  many.write("{\"op\":\"analyze\",\"dimensions\":1,\"constraints\":[")
  for i in 0..<513 {
    if i > 0 {
      many.write(",")
    }
    many.write("{\"left\":{\"variable\":0,\"sign\":1},\"bound\":0}")
  }
  many.write("]}")
  assert_true(process_json(many.to_string()).contains("\"code\":\"limit\""))
  let transfers = StringBuilder()
  transfers.write(
    "{\"op\":\"transfer\",\"dimensions\":1,\"constraints\":[],\"transfers\":[",
  )
  for i in 0..<129 {
    if i > 0 {
      transfers.write(",")
    }
    transfers.write("{\"op\":\"forget\",\"target\":0}")
  }
  transfers.write("]}")
  assert_true(
    process_json(transfers.to_string()).contains("\"code\":\"limit\""),
  )
  assert_true(
    process_json(String::make(200001, ' ')).contains("\"code\":\"limit\""),
  )
}
