// Tabbable-candidate walk: the shared filter behind focus-scope and
// the Dialog trap. Candidates in DOM order, minus disabled / hidden /
// tabindex=-1 / inert-subtree elements.

const CANDIDATE_SELECTOR = [
  "a[href]",
  "button",
  "input",
  "select",
  "textarea",
  "[tabindex]",
  '[contenteditable="true"]',
  "audio[controls]",
  "video[controls]"
].join(", ")

/**
 * The tabbable elements under `container`, in DOM order: candidate
 * tags/tabindexes minus disabled / hidden / tabindex=-1 / inert-subtree /
 * type=hidden elements, with each radio group collapsed to its single
 * real tab stop (see below).
 *
 * @param {Element} container
 * @returns {Element[]}
 */
export function tabbableWithin(container) {
  const candidates = Array.from(container.querySelectorAll(CANDIDATE_SELECTOR)).filter(
    (element) =>
      !element.disabled &&
      !element.hidden &&
      element.getAttribute("tabindex") !== "-1" &&
      element.closest("[inert]") === null &&
      element.type !== "hidden"
  )

  return candidates.filter((element) => isRadioTabStop(element, candidates))
}

// A radio GROUP is one tab stop, not one per radio - the platform's own
// Tab rule: the checked radio represents the group; an all-unchecked group is
// represented by its first radio. Without this, a dialog trap treats every
// radio as an edge candidate and Shift+Tab at the "first" tabbable is
// wrong whenever a radio group sits at either end of the scope.
function isRadioTabStop(element, candidates) {
  if (element.type !== "radio" || !element.name) return true

  const group = candidates.filter(
    (candidate) =>
      candidate.type === "radio" &&
      candidate.name === element.name &&
      candidate.form === element.form
  )
  const checked = group.find((candidate) => candidate.checked)

  return checked ? element === checked : element === group[0]
}
