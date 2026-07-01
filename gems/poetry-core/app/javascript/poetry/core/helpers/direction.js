// Reading direction (Tier 1): the platform mechanism - the closest [dir]
// ancestor - consumed by roving-focus (Left/Right flip) and popper (side flip).

export function directionOf(element) {
  const dir = element.closest("[dir]")?.getAttribute("dir")?.toLowerCase()
  return dir === "rtl" ? "rtl" : "ltr"
}
