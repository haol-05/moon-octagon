///|
fn main {
  let args = @env.args()
  let offset = argument_offset()
  if args.length() == offset + 2 && args[offset] == "--batch" {
    println(@oct.process_batch_json(args[offset + 1]))
  } else if args.length() != offset + 1 {
    println(
      "{\"ok\":false,\"code\":\"usage\",\"message\":\"pass one JSON argument or use scripts/cli.mjs for files\"}",
    )
  } else {
    println(@oct.process_json(args[offset]))
  }
}

///|
#cfg(target="js")
fn argument_offset() -> Int32 {
  2
}

///|
#cfg(not(target="js"))
fn argument_offset() -> Int32 {
  1
}
