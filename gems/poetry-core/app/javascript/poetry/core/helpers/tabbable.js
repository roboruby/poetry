// Tabbable-candidate walk (Tier 1): the shared filter behind focus-scope and
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

export function tabbableWithin(container) {
  return Array.from(container.querySelectorAll(CANDIDATE_SELECTOR)).filter(
    (element) =>
      !element.disabled &&
      !element.hidden &&
      element.getAttribute("tabindex") !== "-1" &&
      element.closest("[inert]") === null &&
      element.type !== "hidden"
  )
}
