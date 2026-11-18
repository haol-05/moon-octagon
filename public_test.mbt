///|
test "library consumer can build query transfer and analyze a loop" {
  let initial = @oct.from_constraints(2, [
    @oct.lower(0, 0L),
    @oct.upper(0, 0L),
    @oct.lower(1, 0L),
    @oct.upper(1, 0L),
  ])
  let r = @oct.analyze_loop(initial, [@oct.upper(0, 9L)], [
    @oct.Assign(0, @oct.positive(0), 1L),
    @oct.Assign(1, @oct.positive(1), 1L),
  ])
  assert_true(
    r.invariant().entails(@oct.relation(@oct.positive(0), @oct.negative(1), 0L)),
  )
  assert_true(
    @oct.verify_invariant(initial, r.invariant(), [@oct.upper(0, 9L)], [
      @oct.Assign(0, @oct.positive(0), 1L),
      @oct.Assign(1, @oct.positive(1), 1L),
    ]),
  )
}
