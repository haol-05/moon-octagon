///|
fn main {
  try {
    let envelope = @oct.from_constraints(2, [
      @oct.lower(0, 0L),
      @oct.lower(1, 0L),
      @oct.relation(@oct.positive(0), @oct.positive(1), 100L),
    ])
    println("Configuration: primary + replica <= 100")
    println(envelope.report().stringify())
    let measurements = @oct.from_constraints(2, [
      @oct.lower(0, 20L),
      @oct.upper(0, 23L),
      @oct.relation(@oct.positive(0), @oct.negative(1), 2L),
      @oct.relation(@oct.negative(0), @oct.positive(1), 2L),
    ])
    println("Sensor consistency: first in [20,23], difference within +/-2")
    println(measurements.report().stringify())
    let start = @oct.top(2).set_constant(0, 0L).set_constant(1, 10L)
    let result = @oct.analyze_loop(start, [@oct.upper(0, 9L)], [
      @oct.Assign(0, @oct.positive(0), 1L),
      @oct.Assign(1, @oct.positive(1), -1L),
    ])
    println("Program loop: x := x+1; y := y-1; invariant x+y=10")
    println(result.invariant().report().stringify())
    println("Iterations: \{result.iterations()}")
  } catch {
    _ => println("Example failed")
  }
}
