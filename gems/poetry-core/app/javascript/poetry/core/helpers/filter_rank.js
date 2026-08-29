// The Command filter spec: deterministic
// substring + a 5-band rank - deliberately NOT a fuzzy command-score. Pure string
// functions so the CI spec table pins the contract: any scoring change is
// a reviewed table change, never a silent reorder of every palette. The
// score's ONLY job is picking the auto-highlighted first match - the
// controller hides score-0 items and NEVER reorders the DOM (DOM order is
// the ranking authority within a band).
//
// Bands: prefix 4 > word-boundary 3 > substring 2 > keyword 1 > hidden 0;
// an empty query scores 1 (everything visible). Matching is
// diacritic-folded ("creme" matches "Crème") and case-insensitive.

export const SCORE_EMPTY_QUERY = 1
export const SCORE_PREFIX = 4
export const SCORE_WORD = 3
export const SCORE_SUBSTRING = 2
export const SCORE_KEYWORD = 1
export const SCORE_HIDDEN = 0

// Words split on whitespace / dash / underscore / slash (the contract's
// word-boundary definition).
const WORD_SPLIT = /[\s\-_/]+/

const ITEM_TEXT_SELECTOR = '[data-slot="command-item-text"], [data-slot="combobox-item-text"]'

// trim + lowercase + NFKD-fold combining marks: diacritic-insensitive
// matching for free in every locale that marks are decorative in (folding
// is always-on - the contract's documented call).
export function normalize(value) {
  return String(value ?? "").trim().toLowerCase().normalize("NFKD").replace(/\p{M}/gu, "")
}

// The pure scorer. label/query arrive RAW (normalization is this
// function's business); keywords is an array of raw strings.
export function scoreText(label, query, keywords = []) {
  const q = normalize(query)

  if (q === "") return SCORE_EMPTY_QUERY

  const folded = normalize(label)

  if (folded.startsWith(q)) return SCORE_PREFIX
  if (folded.split(WORD_SPLIT).some((word) => word !== "" && word.startsWith(q))) return SCORE_WORD
  if (folded.includes(q)) return SCORE_SUBSTRING
  if (keywords.some((keyword) => normalize(keyword) !== "" && normalize(keyword).startsWith(q))) {
    return SCORE_KEYWORD
  }

  return SCORE_HIDDEN
}

// The label an item filters against: data-filter-value overrides (icon-rich
// content), else the item-text part, else the item's own text.
export function filterLabel(item) {
  return item.dataset.filterValue ??
    item.querySelector(ITEM_TEXT_SELECTOR)?.textContent ??
    item.textContent ?? ""
}

// data-keywords: whitespace-separated extra filter terms (the upstream
// keywords prop as a data attribute).
export function filterKeywords(item) {
  return (item.dataset.keywords ?? "").split(/\s+/).filter(Boolean)
}

export function scoreItem(item, query) {
  return scoreText(filterLabel(item), query, filterKeywords(item))
}
