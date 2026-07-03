import { describe, expect, it } from "vitest"
import {
  SCORE_EMPTY_QUERY,
  SCORE_HIDDEN,
  SCORE_KEYWORD,
  SCORE_PREFIX,
  SCORE_SUBSTRING,
  SCORE_WORD,
  filterKeywords,
  filterLabel,
  normalize,
  scoreItem,
  scoreText
} from "@poetry/controllers/helpers/filter_rank"

// THE SPEC TABLE (Command) - the deterministic filter
// contract, verbatim. THE DETERMINISM PROMISE is the component: any "small
// improvement" to scoring silently reorders every palette in every app, so
// scoring changes REQUIRE a table change here (a reviewed, versioned
// event). Bands: prefix 4 > word-boundary 3 > substring 2 > keyword 1 >
// hidden 0; empty query 1; diacritic-folded; case-insensitive; words split
// on whitespace / dash / underscore / slash; keywords match by prefix only.
const SPEC_TABLE = [
  // [label, query, keywords, expected, rule]
  ["Calendar", "", [], SCORE_EMPTY_QUERY, "empty query -> 1 (everything visible)"],
  ["Calendar", "   ", [], SCORE_EMPTY_QUERY, "whitespace-only query trims to empty"],
  ["Calendar", "cal", [], SCORE_PREFIX, "prefix -> 4"],
  ["Calendar", "CAL", [], SCORE_PREFIX, "case-insensitive prefix"],
  ["Calendar", "calendar", [], SCORE_PREFIX, "full-label prefix"],
  ["  Calendar  ", " cal ", [], SCORE_PREFIX, "label and query both trim"],
  ["Search Emoji", "emo", [], SCORE_WORD, "word start (space) -> 3"],
  ["dark-mode", "mod", [], SCORE_WORD, "word start (dash) -> 3"],
  ["user_profile", "prof", [], SCORE_WORD, "word start (underscore) -> 3"],
  ["a/b testing", "test", [], SCORE_WORD, "word start (slash-split words) -> 3"],
  ["Search Emoji", "SEARCH EM", [], SCORE_PREFIX, "prefix outranks the word band"],
  ["Calendar", "end", [], SCORE_SUBSTRING, "mid-word substring -> 2"],
  ["Calendar", "lend", [], SCORE_SUBSTRING, "substring -> 2"],
  ["Calendar", "sched", ["schedule", "dates"], SCORE_KEYWORD, "keyword prefix -> 1"],
  ["Calendar", "dat", ["schedule", "dates"], SCORE_KEYWORD, "any keyword can match"],
  ["Calendar", "ates", ["dates"], SCORE_HIDDEN, "keywords match by PREFIX only"],
  ["Calendar", "cal", ["calendar"], SCORE_PREFIX, "label bands outrank a keyword hit"],
  ["Calendar", "xyz", ["schedule"], SCORE_HIDDEN, "no match -> 0 (hidden)"],
  ["Calendar", "clndr", [], SCORE_HIDDEN, "NOT fuzzy: cmdk's char-gap matching is the documented delta"],
  ["Crème Brûlée", "creme", [], SCORE_PREFIX, "diacritic-folded prefix ('creme' -> Crème)"],
  ["Crème Brûlée", "brulee", [], SCORE_WORD, "diacritic-folded word start"],
  ["Jalapeño", "apeno", [], SCORE_SUBSTRING, "diacritic-folded substring"],
  ["Creme", "crème", [], SCORE_PREFIX, "the QUERY folds too"],
  ["Calendar", "cAlEnD", [], SCORE_PREFIX, "mixed-case query"],
  ["", "cal", [], SCORE_HIDDEN, "empty label never matches a query"],
  ["", "", [], SCORE_EMPTY_QUERY, "empty label still visible on empty query"]
]

describe("helpers/filter_rank", () => {
  describe("the CI spec table", () => {
    it.each(SPEC_TABLE)("scoreText(%j, %j, %j) -> %i (%s)", (label, query, keywords, expected) => {
      expect(scoreText(label, query, keywords)).toBe(expected)
    })
  })

  describe("normalize", () => {
    it("trims, lowercases, and folds combining marks (NFKD)", () => {
      expect(normalize("  Crème Brûlée  ")).toBe("creme brulee")
      expect(normalize("ÉLAN")).toBe("elan")
      expect(normalize(null)).toBe("")
      expect(normalize(undefined)).toBe("")
    })
  })

  describe("the DOM readers", () => {
    const item = (html) => {
      document.body.innerHTML = html
      return document.body.firstElementChild
    }

    it("filterLabel prefers data-filter-value, then the item-text part, then textContent", () => {
      expect(filterLabel(item(
        `<div data-filter-value="Calendar"><span data-slot="command-item-text">📅 Cal</span></div>`
      ))).toBe("Calendar")
      expect(filterLabel(item(
        `<div><span data-slot="command-item-text">Calendar</span><span>⌘C</span></div>`
      ))).toBe("Calendar")
      expect(filterLabel(item(`<div>Calendar</div>`))).toBe("Calendar")
    })

    it("filterKeywords splits data-keywords on whitespace", () => {
      expect(filterKeywords(item(`<div data-keywords="schedule  dates"></div>`))).toEqual(["schedule", "dates"])
      expect(filterKeywords(item(`<div></div>`))).toEqual([])
    })

    it("scoreItem scores through the readers (filter-value override + keywords)", () => {
      const rich = item(
        `<div data-filter-value="Calendar" data-keywords="schedule dates">
           <span data-slot="command-item-text">📅</span>
         </div>`
      )

      expect(scoreItem(rich, "cal")).toBe(SCORE_PREFIX)
      expect(scoreItem(rich, "sched")).toBe(SCORE_KEYWORD)
      expect(scoreItem(rich, "zzz")).toBe(SCORE_HIDDEN)
    })
  })
})
