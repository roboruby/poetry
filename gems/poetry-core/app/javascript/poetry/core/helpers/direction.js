// Reading direction: the platform mechanism - the closest [dir]
// ancestor - consumed by roving-focus (Left/Right flip) and popper (side flip).

/**
 * The reading direction in effect at `element`: the closest `[dir]`
 * ancestor's value. Only an explicit rtl flips - dir="auto", dir="ltr" and
 * no [dir] ancestor at all resolve "ltr".
 *
 * @param {Element} element
 * @returns {"ltr" | "rtl"}
 */
export function directionOf(element) {
  const dir = element.closest("[dir]")?.getAttribute("dir")?.toLowerCase()
  return dir === "rtl" ? "rtl" : "ltr"
}
