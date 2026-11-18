import { describe, it, expect } from "vitest"
import { refusal, test } from "@poetry/agent/a2ui_regex"

// The A2UI regex dialect in the browser: what it matches, what it refuses
// (each refusal by the protocol's token), and the static safety check. The
// server's copy holds the same cases (test/poetry/agent/a2ui/regex_subset_test.rb).
describe("the A2UI regex dialect", () => {
  it("reads anchors as the ends of the value and searches when unanchored", () => {
    expect(test("^abc$", "abc")).toBe(true)
    expect(test("^abc$", "abc\n")).toBe(false)
    expect(test("^b", "a\nb")).toBe(false)
    expect(test("abc", "xxabcxx")).toBe(true)
  })

  it("keeps the class escapes ASCII and the dot off line ends", () => {
    expect(test("^\\d+$", "١٢٣")).toBe(false)
    expect(test("^\\w+$", "café")).toBe(false)
    expect(test("^\\W$", "é")).toBe(true)
    expect(test("\\b", "é")).toBe(false)
    expect(test("\\Bx", "ax")).toBe(true)
    expect(test("^a.b$", "a\nb")).toBe(false)
    expect(test("^.$", " ")).toBe(false)
    expect(test("^.$", "😀")).toBe(true)
    expect(test("^\\s$", " ")).toBe(true)
    expect(test("^abc$", "ABC")).toBe(false)
  })

  it("takes the dialect's escapes, classes, groups and quantifiers", () => {
    expect(test("^\\u{1F600}+$", "😀😀")).toBe(true)
    expect(test("^\\u0041\\x42\\0$", "AB\0")).toBe(true)
    expect(test("^[\\b\\t\\-]+$", "\b\t-")).toBe(true)
    expect(test("^[^a-c]$", "\n")).toBe(true)
    expect(test("^(?:a|b)+c\\/$", "abac/")).toBe(true)
    expect(test("^(?=.*\\d)(?!.*x).{8,}$", "secret42")).toBe(true)
    expect(test("^a{2,3}?$", "aaa")).toBe(true)
    expect(test("^a{2}?$", "")).toBe(false)
    expect(test("", "anything")).toBe(true)
    expect(test("a||b", "zzz")).toBe(true)
  })

  it("refuses what the dialect leaves out as unsupported syntax", () => {
    const refused = ["(a)\\1", "\\k<n>", "(?<=a)b", "(?<!a)b", "(?<n>a)", "(?i)a", "\\p{L}", "\\cA", "\\07", "\\q", "[\\B]",
      "a{", "a}", "]", "a**", "a++", "^*", "(?=a)+", "a{2,1}", "a{,2}", "a{1", "a{99999}", "x{1,99999}",
      "[a-\\d]", "[z-a]", "[]", "[a&&b]", "[[a]]", "[a--b]", "[a", "(a", "a)", "\\", "\\x4", "\\u12",
      "\\u{}", "\\u{110000}", "\\uD83D", "\\u{D800}", "[a-", "a\uD83Db", "[\uD83D]"]
    for (const pattern of refused) expect(refusal(pattern), pattern).toBe("UNSUPPORTED_SYNTAX")
    expect(test("(a)\\1", "aa")).toBe(null)
  })

  it("names the safety rule a pattern breaks", () => {
    expect(refusal("a".repeat(257))).toBe("PATTERN_TOO_LONG")
    expect(refusal("a".repeat(256))).toBe(null)
    const broken = {
      "(a+)+$": "NESTED_QUANTIFIER", "(a*){2,5}": "NESTED_QUANTIFIER", "(?:(?=a+)b)*": "NESTED_QUANTIFIER",
      "(a|ab)*c": "OVERLAPPING_ALTERNATION", "(\\d|[0-5])+": "OVERLAPPING_ALTERNATION", "((a)|(ab)){1,}": "OVERLAPPING_ALTERNATION",
      "\\d+\\d+": "ADJACENT_OVERLAP", "\\d+\\s*\\d+": "ADJACENT_OVERLAP", "a+(?=a)b?a*": "ADJACENT_OVERLAP",
      "(a+)(a*)": "ADJACENT_OVERLAP", "x(?:.*.*)": "ADJACENT_OVERLAP"
    }
    for (const [pattern, rule] of Object.entries(broken)) expect(refusal(pattern), pattern).toBe(rule)
    const safe = ["(?:ab+)?c", "(a+)?", "(a?)*", "(a|b)*c", "\\w+\\s+\\w+", "a+ba+", "(?:a|b){1,1000}", "a{0}a+", "^[a-z]+@[a-z]+\\.com$"]
    for (const pattern of safe) expect(refusal(pattern), pattern).toBe(null)
  })

  it("does not match a value past the cap, and keeps answering once its cache turns over", () => {
    expect(test("^a+$", "a".repeat(4096))).toBe(true)
    expect(test("^a+$", "a".repeat(4097))).toBe(false)
    expect(test("^.+$", "😀".repeat(4096))).toBe(true)
    for (let index = 0; index <= 256; index += 1) refusal(`^fill${index}$`)
    expect(test("^a+$", "aaa")).toBe(true)
  })
})
