///|
/// One basic block: a guard, a straight-line transfer body, and successors.
pub(all) struct Block {
  conditions : Array[Constraint]
  body : Array[Transfer]
  successors : Array[Int32]
}

///|
pub(all) enum CfgStatus {
  CfgStable
  CfgBudgetExhausted
}

///|
pub(all) struct CfgResult {
  states : Array[Octagon]
  status : CfgStatus
  steps : Int32
}

///|
/// Bounded worklist analysis over a small control-flow graph. Every block is
/// analysed with the octagon domain; joins happen at successors and widening
/// starts after `widen_after` visits of the same successor. The result keeps
/// partial states when the step budget runs out, exactly like the loop
/// analysis, so callers must check `status`.
pub fn analyze_blocks(
  entry : Octagon,
  blocks : Array[Block],
  max_steps~ : Int32 = 512,
  widen_after~ : Int32 = 2,
) -> CfgResult raise OctagonError {
  if blocks.length() == 0 || blocks.length() > 64 {
    raise Limit("cfg: block count must be 1..64")
  }
  if max_steps < 1 || max_steps > 4096 {
    raise Limit("cfg: max_steps must be 1..4096")
  }
  if widen_after < 0 || widen_after > 16 {
    raise Limit("cfg: widen_after must be 0..16")
  }
  let n = entry.dimensions
  for b in blocks {
    ignore(bottom(n).refine(b.conditions).execute(b.body))
    for s in b.successors {
      if s < 0 || s >= blocks.length() {
        raise Invalid(
          "cfg: successor index \{s} outside 0..\{blocks.length() - 1}",
        )
      }
    }
  }
  if entry.empty {
    let states : Array[Octagon] = Array::makei(blocks.length(), _ => bottom(n))
    return { states, status: CfgStable, steps: 0, }
  }
  let states : Array[Octagon] = Array::makei(blocks.length(), _ => bottom(n))
  states[0] = entry.canonical()
  let visits : Array[Int32] = Array::make(blocks.length(), 0)
  let worklist : Array[Int32] = [0]
  let mut cursor = 0
  let mut steps = 0
  while cursor < worklist.length() && steps < max_steps {
    let index = worklist[cursor]
    cursor = cursor + 1
    let block = blocks[index]
    let out = states[index].refine(block.conditions).execute(block.body)
    for successor in block.successors {
      visits[successor] = visits[successor] + 1
      let back_edge = successor <= index
      let candidate = if back_edge && visits[successor] > widen_after {
        states[successor].widen(out)
      } else {
        states[successor].join(out)
      }
      if !candidate.subset_of(states[successor]) {
        states[successor] = candidate
        worklist.push(successor)
      }
    }
    steps = steps + 1
  }
  {
    states,
    status: if cursor >= worklist.length() {
      CfgStable
    } else {
      CfgBudgetExhausted
    },
    steps,
  }
}
