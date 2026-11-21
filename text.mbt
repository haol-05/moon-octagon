///|
/// Errors from the textual front-end carry the statement index, not a byte
/// offset, because statements are the unit users edit.
priv enum Token {
  TInt(Int64)
  TVar(Int32)
  TPlus
  TMinus
  TLe
  TGe
  TEq
  TLBracket
  TRBracket
  TComma
  TIn
  TSep
  TEnd
}

///|
fn tokenize(input : String) -> Array[Token] raise OctagonError {
  let chars : Array[Char] = []
  for ch in input.iter() {
    chars.push(ch)
  }
  let tokens : Array[Token] = []
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch == ' ' || ch == '\t' || ch == '\r' {
      i = i + 1
    } else if ch == '\n' || ch == ';' {
      tokens.push(TSep)
      i = i + 1
    } else if ch == '#' {
      while i < chars.length() && chars[i] != '\n' {
        i = i + 1
      }
    } else if ch == '<' {
      if i + 1 < chars.length() && chars[i + 1] == '=' {
        tokens.push(TLe)
        i = i + 2
      } else {
        raise Invalid("text: expected <= after '<'")
      }
    } else if ch == '>' {
      if i + 1 < chars.length() && chars[i + 1] == '=' {
        tokens.push(TGe)
        i = i + 2
      } else {
        raise Invalid("text: expected >= after '>'")
      }
    } else if ch == '=' {
      tokens.push(TEq)
      i = i + 1
    } else if ch == '+' {
      tokens.push(TPlus)
      i = i + 1
    } else if ch == '-' {
      tokens.push(TMinus)
      i = i + 1
    } else if ch == '[' {
      tokens.push(TLBracket)
      i = i + 1
    } else if ch == ']' {
      tokens.push(TRBracket)
      i = i + 1
    } else if ch == ',' {
      tokens.push(TComma)
      i = i + 1
    } else if ch.is_ascii_digit() {
      let mut value = 0L
      while i < chars.length() && chars[i].is_ascii_digit() {
        value = value * 10L + (chars[i].to_int() - 48).to_int64()
        if value > 1000000000000000L {
          raise Limit("text: integer literal exceeds 10^15")
        }
        i = i + 1
      }
      tokens.push(TInt(value))
    } else if ch == 'x' {
      i = i + 1
      let mut value = 0
      let mut digits = false
      while i < chars.length() && chars[i].is_ascii_digit() {
        value = value * 10 + (chars[i].to_int() - 48)
        digits = true
        if value > 1000000 {
          raise Limit("text: variable index exceeds 1000000")
        }
        i = i + 1
      }
      if !digits {
        raise Invalid("text: expected a decimal variable index after 'x'")
      }
      tokens.push(TVar(value))
    } else if ch == 'i' &&
      i + 1 < chars.length() &&
      chars[i + 1] == 'n' &&
      (i + 2 >= chars.length() || !chars[i + 2].is_ascii_alphabetic()) {
      tokens.push(TIn)
      i = i + 2
    } else {
      raise Invalid("text: unexpected character in constraint input")
    }
  }
  tokens.push(TEnd)
  tokens
}

///|
fn at(tokens : Array[Token], index : Int32) -> Token {
  if index >= 0 && index < tokens.length() {
    tokens[index]
  } else {
    TEnd
  }
}

///|
fn check_separator(
  tokens : Array[Token],
  index : Int32,
  statement : Int32,
) -> Unit raise OctagonError {
  match at(tokens, index) {
    TSep | TEnd => ()
    _ => raise Invalid("text: statement \{statement} has trailing tokens")
  }
}

///|
fn read_int(
  tokens : Array[Token],
  index : Int32,
) -> (Int64, Int32) raise OctagonError {
  let mut cursor = index
  let sign = match at(tokens, cursor) {
    TMinus => {
      cursor = cursor + 1
      -1L
    }
    TPlus => {
      cursor = cursor + 1
      1L
    }
    _ => 1L
  }
  let value = match at(tokens, cursor) {
    TInt(value) => value
    _ => raise Invalid("text: expected an integer literal")
  }
  (sign * value, cursor + 1)
}

///|
fn parse_interval(
  dimensions : Int32,
  tokens : Array[Token],
  start : Int32,
  statement : Int32,
) -> (Array[Constraint], Int32) raise OctagonError {
  let v = match at(tokens, start) {
    TVar(v) => v
    _ => raise Invalid("text: expected a variable")
  }
  variable(dimensions, v)
  if !(at(tokens, start + 1) is TIn) {
    raise Invalid("text: expected 'in' after the variable")
  }
  if !(at(tokens, start + 2) is TLBracket) {
    raise Invalid("text: expected '[' in an interval")
  }
  let (lo, after_lo) = read_int(tokens, start + 3)
  if !(at(tokens, after_lo) is TComma) {
    raise Invalid("text: expected ',' in an interval")
  }
  let (hi, after_hi) = read_int(tokens, after_lo + 1)
  if !(at(tokens, after_hi) is TRBracket) {
    raise Invalid("text: expected ']' in an interval")
  }
  if lo > hi {
    raise Invalid("text: interval lower bound exceeds its upper bound")
  }
  let next = after_hi + 1
  check_separator(tokens, next, statement)
  ([lower(v, lo), upper(v, hi)], next)
}

///|
fn negate_constraint(c : Constraint) -> Constraint {
  {
    left: { variable: c.left.variable, sign: -c.left.sign, },
    right: match c.right {
      None => None
      Some(t) => Some({ variable: t.variable, sign: -t.sign, })
    },
    bound: -c.bound,
  }
}

///|
fn parse_expression(
  dimensions : Int32,
  tokens : Array[Token],
  start : Int32,
  statement : Int32,
) -> (Array[Constraint], Int32) raise OctagonError {
  let mut index = start
  let left_sign = match at(tokens, index) {
    TMinus => {
      index = index + 1
      -1
    }
    TPlus => {
      index = index + 1
      1
    }
    _ => 1
  }
  let left_var = match at(tokens, index) {
    TVar(v) => v
    _ => raise Invalid("text: expected a variable in an expression")
  }
  variable(dimensions, left_var)
  index = index + 1
  let mut right_var : Int32? = None
  let mut right_sign = 1
  match at(tokens, index) {
    TPlus | TMinus => {
      right_sign = if at(tokens, index) is TPlus { 1 } else { -1 }
      index = index + 1
      let v = match at(tokens, index) {
        TVar(v) => v
        _ => raise Invalid("text: expected a variable after the sign")
      }
      variable(dimensions, v)
      right_var = Some(v)
      index = index + 1
    }
    _ => ()
  }
  let relation_token = at(tokens, index)
  index = index + 1
  if !(relation_token is TLe) &&
    !(relation_token is TGe) &&
    !(relation_token is TEq) {
    raise Invalid("text: expected <=, >= or = before the bound")
  }
  let (raw_bound, after_bound) = read_int(tokens, index)
  index = after_bound
  check_separator(tokens, index, statement)
  let positive = relation_token is TLe || relation_token is TEq
  let sign = if positive { left_sign } else { -left_sign }
  let bound = if positive { raw_bound } else { -raw_bound }
  let left : Term = { variable: left_var, sign, }
  let right : Term? = match right_var {
    None => None
    Some(v) =>
      Some({
        variable: v,
        sign: if positive {
          right_sign
        } else {
          -right_sign
        },
      })
  }
  let c : Constraint = { left, right, bound, }
  validate_constraint(dimensions, c)
  if relation_token is TEq {
    let flipped = negate_constraint(c)
    validate_constraint(dimensions, flipped)
    ([c, flipped], index)
  } else {
    ([c], index)
  }
}

///|
/// Parse a small line-oriented constraint language for the integer octagon
/// domain. Statements are separated by newlines or semicolons; '#' starts a
/// comment. Supported forms:
///
///   x0 in [0, 100]
///   x0 <= 100
///   x0 >= 0
///   x0 + x1 <= 100
///   x0 - x1 <= 2
///   -x0 + x1 <= 2
///
/// Dimensions are supplied by the caller; all indices and bounds are validated.
pub fn parse_constraints(
  dimensions : Int32,
  input : String,
) -> Array[Constraint] raise OctagonError {
  validate_dimensions(dimensions)
  if input.length() > 200000 {
    raise Limit("text: input exceeds 200000 UTF-16 units")
  }
  let tokens = tokenize(input)
  let result : Array[Constraint] = []
  let mut index = 0
  let mut statement = 0
  while true {
    while at(tokens, index) is TSep {
      index = index + 1
    }
    if at(tokens, index) is TEnd {
      break
    }
    let (parsed, next) = if at(tokens, index) is TVar(_) &&
      at(tokens, index + 1) is TIn {
      parse_interval(dimensions, tokens, index, statement)
    } else {
      parse_expression(dimensions, tokens, index, statement)
    }
    for c in parsed {
      result.push(c)
    }
    if result.length() > 4096 {
      raise Limit("text: at most 4096 constraints")
    }
    index = next
    statement = statement + 1
  }
  result
}

///|
/// Serialise a non-empty domain as a parseable constraint text. The empty text
/// denotes the top domain. Bottom has no finite conjunction and raises Invalid.
pub fn Octagon::to_text(self : Octagon) -> String raise OctagonError {
  if self.empty {
    raise Invalid("bottom has no finite text form")
  }
  if self.is_top() {
    return ""
  }
  let s = self.canonical()
  let ranges = s.intervals()
  let sb = StringBuilder()
  let mut first = true
  for i in 0..<self.dimensions {
    match ranges[i] {
      None => ()
      Some(r) =>
        match (r.lower, r.upper) {
          (Some(lo), Some(hi)) => {
            if !first {
              sb.write("\n")
            }
            first = false
            sb.write("x\{i} in [\{lo}, \{hi}]")
          }
          (Some(lo), None) => {
            if !first {
              sb.write("\n")
            }
            first = false
            sb.write("x\{i} >= \{lo}")
          }
          (None, Some(hi)) => {
            if !first {
              sb.write("\n")
            }
            first = false
            sb.write("x\{i} <= \{hi}")
          }
          (None, None) => ()
        }
    }
  }
  for i in 0..<self.dimensions {
    for j in (i + 1)..<self.dimensions {
      let forms = [
        s.matrix[2 * i][2 * j + 1],
        s.matrix[2 * i][2 * j],
        s.matrix[2 * i + 1][2 * j + 1],
        s.matrix[2 * i + 1][2 * j],
      ]
      for k in 0..<4 {
        if forms[k] != INF {
          if !first {
            sb.write("\n")
          }
          first = false
          let text = match k {
            0 => render_constraint(relation(positive(i), positive(j), forms[k]))
            1 => render_constraint(relation(positive(i), negative(j), forms[k]))
            2 => render_constraint(relation(negative(i), positive(j), forms[k]))
            _ => render_constraint(relation(negative(i), negative(j), forms[k]))
          }
          sb.write(text)
        }
      }
    }
  }
  sb.to_string()
}
