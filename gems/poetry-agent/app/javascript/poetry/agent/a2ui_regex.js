// The A2UI regex dialect in the browser: the portable subset of ECMAScript
// pattern syntax (Unicode mode, no flags) the protocol defines for `regex`,
// with the static safety check it runs before any matching. The server's
// copy is Poetry::Agent::A2UI::RegexSubset; the two answer alike, so a check
// reads the same as the person types and when the form arrives.
//
// A pattern is parsed here first. One outside the dialect, or one the safety
// check refuses, is never compiled: `refusal` names why by the protocol's
// token, and `test` answers null so the server reports it. A pattern that
// passes runs on the browser's own engine in Unicode mode, which already
// reads the dialect as written (`$` as the end of the value, ASCII `\d`,
// `\w` and `\b`).

// The longest pattern, and the longest value a pattern is matched against, in code points.
const MAX_PATTERN = 256
const MAX_VALUE = 4096
// The largest count a {n,m} quantifier may name.
const MAX_BOUND = 65535
// The last code point, and the surrogates no escape may name.
const LAST = 0x10FFFF
const SURROGATES = [0xD800, 0xDFFF]
// How many compiled patterns are kept.
const CACHE_SIZE = 256

// Code point ranges as [low, high] pairs: sorted and merged, their complement, whether two lists meet.
const normalize = (ranges) => {
  const merged = []
  for (const [low, high] of [...ranges].sort((a, b) => a[0] - b[0] || a[1] - b[1])) {
    const last = merged[merged.length - 1]
    if (last && low <= last[1] + 1) last[1] = Math.max(last[1], high)
    else merged.push([low, high])
  }
  return merged
}
const complement = (ranges) => {
  const gaps = []
  let from = 0
  for (const [low, high] of ranges) {
    if (low > from) gaps.push([from, low - 1])
    from = high + 1
  }
  if (from <= LAST) gaps.push([from, LAST])
  return gaps
}
const overlap = (left, right) => left.some(([low, high]) => right.some(([otherLow, otherHigh]) => low <= otherHigh && otherLow <= high))

const DIGIT = [[0x30, 0x39]]
const WORD = [[0x30, 0x39], [0x41, 0x5A], [0x5F, 0x5F], [0x61, 0x7A]]
// \s: ECMAScript's WhiteSpace and LineTerminator.
const SPACE = [[0x09, 0x0D], [0x20, 0x20], [0xA0, 0xA0], [0x1680, 0x1680], [0x2000, 0x200A], [0x2028, 0x2029], [0x202F, 0x202F], [0x205F, 0x205F], [0x3000, 0x3000], [0xFEFF, 0xFEFF]]
const CLASSES = { d: DIGIT, D: complement(DIGIT), w: WORD, W: complement(WORD), s: SPACE, S: complement(SPACE) }
// What the dot takes: everything but the line terminators.
const DOT = complement([[0x0A, 0x0A], [0x0D, 0x0D], [0x2028, 0x2029]])
const CONTROLS = { t: 0x09, n: 0x0A, v: 0x0B, f: 0x0C, r: 0x0D }
// The characters an identity escape may name.
const SYNTAX = "^$\\.*+?()[]{}|/"

// A refusal: an error carrying the protocol's token.
const rejected = (token, detail) => Object.assign(new Error(`${token}: ${detail}`), { token })

// The dialect's parser: a pattern to its tree, or a refusal. Nodes are plain
// objects by type: chars (ranges), group, look, anchor, concat (items), alt
// (branches), repeat (child, min, max - null when unbounded).
const parse = (pattern) => {
  const chars = [...pattern]
  let at = 0
  const refuse = (detail) => { throw rejected("UNSUPPORTED_SYNTAX", detail) }
  const eof = () => at >= chars.length
  const peek = (ahead = 0) => chars[at + ahead]
  const take = () => (eof() ? refuse("the pattern ends early") : chars[at++])
  const eat = (char) => {
    if (peek() !== char) return false
    at += 1
    return true
  }
  const quantifierAt = (char) => char !== undefined && "*+?{".includes(char)
  const scalar = (code) => (code >= SURROGATES[0] && code <= SURROGATES[1] ? refuse("a surrogate") : code)
  const single = (code) => ({ type: "chars", ranges: [[code, code]] })

  const hex = (digits) => {
    let text = ""
    for (let index = 0; index < digits; index += 1) text += take()
    return /^[0-9a-fA-F]+$/.test(text) ? parseInt(text, 16) : refuse("a malformed hexadecimal escape")
  }
  const bracedHex = () => {
    let text = ""
    while (!eof() && peek() !== "}") text += take()
    if (!eat("}") || !/^[0-9a-fA-F]+$/.test(text)) refuse("a malformed \\u{...} escape")
    if (text.replace(/^0+/, "").length > 6 || parseInt(text, 16) > LAST) refuse("a \\u{...} escape past U+10FFFF")
    return scalar(parseInt(text, 16))
  }
  const numeric = (char) => {
    if (char === "0") return /[0-9]/.test(peek() ?? "") ? refuse("an octal escape") : 0
    if (char === "x") return hex(2)
    if (char === "u") return eat("{") ? bracedHex() : scalar(hex(4))
    return refuse("a backreference")
  }
  // An escape after its backslash: { code }, { ranges } or { anchor }.
  const escape = (inClass) => {
    const char = take()
    if (char === "b") return inClass ? { code: 0x08 } : { anchor: "boundary" }
    if (char === "B") return inClass ? refuse("\\B inside a character class") : { anchor: "notBoundary" }
    if (Object.hasOwn(CLASSES, char)) return { ranges: CLASSES[char] }
    if (Object.hasOwn(CONTROLS, char)) return { code: CONTROLS[char] }
    if (/^[0-9xu]$/.test(char)) return { code: numeric(char) }
    if (SYNTAX.includes(char) || (inClass && char === "-")) return { code: char.codePointAt(0) }
    return refuse(`the escape \\${char}`)
  }

  // One member of a class: its code point (null for a class escape) and its ranges.
  const classAtom = () => {
    if (eat("\\")) {
      const escaped = escape(true)
      return escaped.ranges ? [null, escaped.ranges] : [escaped.code, [[escaped.code, escaped.code]]]
    }
    if (peek() === "[") refuse("a nested character class")
    if (peek() === "&" && peek(1) === "&") refuse("character class intersection")
    const code = scalar(take().codePointAt(0))
    return [code, [[code, code]]]
  }
  const classItem = () => {
    const [low, ranges] = classAtom()
    if (peek() !== "-" || peek(1) === "]") return ranges
    take()
    if (peek() === "-") refuse("character class subtraction")
    const [high] = classAtom()
    if (low === null || high === null) refuse("a class escape as the end of a range")
    if (low > high) refuse("a character class range out of order")
    return [[low, high]]
  }
  const charClass = () => {
    const negated = eat("^")
    const ranges = []
    while (!eof() && peek() !== "]") ranges.push(...classItem())
    if (!eat("]")) refuse("an unclosed character class")
    if (ranges.length === 0) refuse("an empty character class")
    const set = normalize(ranges)
    return { type: "chars", ranges: negated ? complement(set) : set }
  }

  const count = () => {
    let digits = ""
    while (/[0-9]/.test(peek() ?? "")) digits += take()
    if (digits === "") refuse("a malformed {n,m} quantifier")
    if (digits.length > 5 || Number(digits) > MAX_BOUND) refuse(`a quantifier bound over ${MAX_BOUND}`)
    return Number(digits)
  }
  const bracedBounds = () => {
    const min = count()
    if (eat("}")) return [min, min]
    if (!eat(",")) refuse("a malformed {n,m} quantifier")
    if (eat("}")) return [min, null]
    const max = count()
    if (!eat("}")) refuse("a malformed {n,m} quantifier")
    if (max < min) refuse("a quantifier whose minimum exceeds its maximum")
    return [min, max]
  }
  const quantifier = (child) => {
    const char = take()
    const [min, max] = char === "*" ? [0, null] : char === "+" ? [1, null] : char === "?" ? [0, 1] : bracedBounds()
    eat("?")
    if (quantifierAt(peek())) refuse("a chained or possessive quantifier")
    return { type: "repeat", child, min, max }
  }

  const group = () => {
    let kind = ""
    if (eat("?")) {
      kind = take()
      if (!":=!".includes(kind)) refuse(`the group extension (?${kind}`)
    }
    const child = disjunction()
    if (!eat(")")) refuse("an unclosed group")
    return kind === "" || kind === ":" ? { type: "group", child } : { type: "look", child }
  }
  const atom = () => {
    const char = take()
    if (char === "^" || char === "$") return { type: "anchor" }
    if (char === ".") return { type: "chars", ranges: DOT }
    if (char === "[") return charClass()
    if (char === "(") return group()
    if (char === "\\") {
      const escaped = escape(false)
      if (escaped.anchor) return { type: "anchor" }
      return escaped.ranges ? { type: "chars", ranges: escaped.ranges } : single(escaped.code)
    }
    if ("{}]".includes(char)) refuse(`an unescaped ${char}`)
    if ("*+?".includes(char)) refuse(`nothing to repeat before ${char}`)
    return single(scalar(char.codePointAt(0)))
  }
  const term = () => {
    const node = atom()
    if (!quantifierAt(peek())) return node
    if (node.type === "anchor" || node.type === "look") refuse("a quantifier on an assertion")
    return quantifier(node)
  }
  const alternative = () => {
    const items = []
    while (!eof() && peek() !== "|" && peek() !== ")") items.push(term())
    return items.length === 1 ? items[0] : { type: "concat", items }
  }
  const disjunction = () => {
    const branches = [alternative()]
    while (eat("|")) branches.push(alternative())
    return branches.length === 1 ? branches[0] : { type: "alt", branches }
  }

  const tree = disjunction()
  if (!eof()) refuse("an unmatched closing parenthesis")
  return tree
}

// A node's children (lookahead bodies among them), and the node under its groups.
const children = (node) => {
  if (node.type === "group" || node.type === "look" || node.type === "repeat") return [node.child]
  if (node.type === "concat") return node.items
  return node.type === "alt" ? node.branches : []
}
const unwrap = (node) => (node.type === "group" ? unwrap(node.child) : node)
const any = (node, found) => found(node) || children(node).some((child) => any(child, found))
const unbounded = (node) => node.type === "repeat" && node.max === null

// Whether a node can match the empty string.
const nullable = (node) => {
  if (node.type === "anchor" || node.type === "look") return true
  if (node.type === "chars") return false
  if (node.type === "repeat") return node.min === 0 || nullable(node.child)
  if (node.type === "alt") return node.branches.some(nullable)
  return children(node).every(nullable)
}
// The code points a match of a node can start with.
const first = (node) => {
  if (node.type === "chars") return node.ranges
  if (node.type === "group") return first(node.child)
  if (node.type === "repeat") return node.max === 0 ? [] : first(node.child)
  if (node.type === "alt") return normalize(node.branches.flatMap(first))
  if (node.type !== "concat") return []
  const sets = []
  for (const item of node.items) {
    sets.push(...first(item))
    if (!nullable(item)) break
  }
  return normalize(sets)
}
// Every code point a node can consume, lookaheads apart.
const consumed = (node) => {
  if (node.type === "chars") return node.ranges
  if (node.type === "look" || node.type === "anchor") return []
  if (node.type === "repeat") return node.max === 0 ? [] : consumed(node.child)
  return normalize(children(node).flatMap(consumed))
}

// Rule 2: a quantifier above one over a subexpression with an unbounded quantifier.
const nestedQuantifier = (node) => node.type === "repeat" && (node.max === null || node.max > 1) && any(node.child, unbounded)
// Rule 3: an unbounded quantifier over an alternation whose branches can start alike.
const overlappingAlternation = (node) => {
  if (!unbounded(node)) return false
  const inner = unwrap(node.child)
  if (inner.type !== "alt") return false
  const starts = inner.branches.map((branch) => first(unwrap(branch)))
  return starts.some((left, index) => starts.slice(index + 1).some((right) => overlap(left, right)))
}
// Rule 4: two unbounded atoms that share a character, with nothing between them that must match.
const adjacentOverlap = (node) => node.type === "concat" && node.items.some((item, index) => {
  const head = unwrap(item)
  if (!unbounded(head)) return false
  const set = consumed(head.child)
  for (const following of node.items.slice(index + 1)) {
    const next = unwrap(following)
    if (unbounded(next) && overlap(set, consumed(next.child))) return true
    if (!nullable(following)) return false
  }
  return false
})

// Parses a pattern and runs the safety check, throwing the first refusal.
const check = (pattern) => {
  const length = [...pattern].length
  if (length > MAX_PATTERN) throw rejected("PATTERN_TOO_LONG", `${length} code points, over ${MAX_PATTERN}`)
  const tree = parse(pattern)
  if (any(tree, nestedQuantifier)) throw rejected("NESTED_QUANTIFIER", "a quantifier that repeats more than once holds an unbounded one")
  if (any(tree, overlappingAlternation)) throw rejected("OVERLAPPING_ALTERNATION", "an unbounded quantifier repeats branches that can start alike")
  if (any(tree, adjacentOverlap)) throw rejected("ADJACENT_OVERLAP", "two unbounded quantifiers side by side can match one character")
}

const compiled = new Map()

// The browser's expression for a checked pattern, or the refusal's token.
const compile = (pattern) => {
  if (compiled.has(pattern)) return compiled.get(pattern)
  let held
  try {
    check(pattern)
    held = new RegExp(pattern, "u")
  } catch (error) {
    held = error.token ?? "UNSUPPORTED_SYNTAX"
  }
  if (compiled.size >= CACHE_SIZE) compiled.delete(compiled.keys().next().value)
  compiled.set(pattern, held)
  return held
}

/**
 * Why the A2UI regex dialect or its safety check refuses a pattern.
 *
 * @param {string} pattern the pattern as the surface wrote it
 * @returns {string|null} the protocol's token (UNSUPPORTED_SYNTAX, PATTERN_TOO_LONG,
 *   NESTED_QUANTIFIER, OVERLAPPING_ALTERNATION or ADJACENT_OVERLAP), or null for a pattern it takes
 */
export const refusal = (pattern) => {
  const held = compile(String(pattern))
  return typeof held === "string" ? held : null
}

/**
 * Whether a pattern of the dialect matches anywhere in a value. A value past
 * 4,096 code points does not match.
 *
 * @param {string} pattern the pattern as the surface wrote it
 * @param {string} value the value searched
 * @returns {boolean|null} the answer, or null for a pattern the dialect or its
 *   safety check refuses (the server reports why)
 */
export const test = (pattern, value) => {
  const held = compile(String(pattern))
  if (typeof held === "string") return null
  const text = String(value)
  if (text.length > MAX_VALUE && [...text].length > MAX_VALUE) return false
  return held.test(text)
}
