///|
test "cfg diamond joins both branches" {
  let entry = from_constraints(1, [lower(0, 0L), upper(0, 10L)])
  let blocks = [
    { conditions: [], body: [], successors: [1, 2], },
    {
      conditions: [upper(0, 5L)],
      body: [Assign(0, positive(0), 1L)],
      successors: [3],
    },
    {
      conditions: [lower(0, 6L)],
      body: [Assign(0, positive(0), -1L)],
      successors: [3],
    },
    { conditions: [], body: [], successors: [], },
  ]
  let r = analyze_blocks(entry, blocks)
  match r.status {
    CfgStable => ()
    _ => fail("expected a stable diamond")
  }
  assert_eq(
    r.states[3].interval(0),
    Some({ lower: Some(1L), upper: Some(9L), }),
  )
  assert_eq(
    r.states[1].interval(0),
    Some({ lower: Some(0L), upper: Some(10L), }),
  )
  assert_eq(
    r.states[2].interval(0),
    Some({ lower: Some(0L), upper: Some(10L), }),
  )
}

///|
test "cfg self loop stabilises with widening" {
  let entry = from_constraints(1, [lower(0, 0L), upper(0, 0L)])
  let blocks = [
    {
      conditions: [upper(0, 9L)],
      body: [Assign(0, positive(0), 1L)],
      successors: [0, 1],
    },
    { conditions: [], body: [], successors: [], },
  ]
  let r = analyze_blocks(entry, blocks)
  match r.status {
    CfgStable => ()
    _ => fail("expected the loop to stabilize")
  }
  assert_eq(
    r.states[1].interval(0),
    Some({ lower: Some(1L), upper: Some(10L), }),
  )
  assert_true(r.steps > 1)
}

///|
test "cfg budget exhaustion is reported and partial states kept" {
  let entry = from_constraints(1, [lower(0, 0L), upper(0, 0L)])
  let blocks = [
    {
      conditions: [upper(0, 9L)],
      body: [Assign(0, positive(0), 1L)],
      successors: [0],
    },
  ]
  let r = analyze_blocks(entry, blocks, max_steps=1)
  match r.status {
    CfgBudgetExhausted => ()
    _ => fail("expected budget exhaustion")
  }
  assert_eq(r.steps, 1)
}

///|
test "cfg validation rejects empty bad successors and invalid blocks" {
  let entry = top(1)
  let none : Array[Block] = []
  let empty = try {
    ignore(analyze_blocks(entry, none))
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(empty)
  let bad_successor = try {
    ignore(
      analyze_blocks(entry, [{ conditions: [], body: [], successors: [1], }]),
    )
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(bad_successor)
  let bad_constraint = try {
    ignore(
      analyze_blocks(entry, [
        {
          conditions: [
            { left: { variable: 0, sign: 0, }, right: None, bound: 0L, },
          ],
          body: [],
          successors: [],
        },
      ]),
    )
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(bad_constraint)
  let bottom_result = analyze_blocks(bottom(1), [
    { conditions: [], body: [], successors: [], },
  ])
  match bottom_result.status {
    CfgStable => ()
    _ => fail("empty entry must be stable")
  }
  assert_true(bottom_result.states[0].is_bottom())
}

///|
test "cfg linear chain keeps every block reachable" {
  let entry = from_constraints(1, [lower(0, 0L), upper(0, 4L)])
  let blocks = [
    {
      conditions: [upper(0, 3L)],
      body: [Assign(0, positive(0), 1L)],
      successors: [1],
    },
    { conditions: [], body: [Set(0, 0L)], successors: [2], },
    { conditions: [], body: [], successors: [], },
  ]
  let r = analyze_blocks(entry, blocks)
  match r.status {
    CfgStable => ()
    _ => fail("expected a stable chain")
  }
  assert_eq(
    r.states[1].interval(0),
    Some({ lower: Some(1L), upper: Some(4L), }),
  )
  assert_eq(
    r.states[2].interval(0),
    Some({ lower: Some(0L), upper: Some(0L), }),
  )
  assert_eq(r.steps, 3)
}

///|
test "cfg option bounds are validated" {
  let entry = top(1)
  let blocks = [{ conditions: [], body: [], successors: [], }]
  let steps = try {
    ignore(analyze_blocks(entry, blocks, max_steps=0))
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(steps)
  let widen = try {
    ignore(analyze_blocks(entry, blocks, widen_after=17))
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(widen)
}
