// The composed-DOM duplicate-id tripwire: the ONLY
// check that sees the page as actually composed - static lints can't see
// across templates, frames, streams, or cached fragments, so this scans
// the live document for duplicate [id] values after every composition
// event and reports what it finds. Development tooling: install via
// poetry_id_integrity_script (dev layouts); never wired in production.
//
// Duplicate ids are always a bug regardless of source (ARIA IDREFs
// resolve to the first match only), and under StableId they are the
// signature of the two documented hazards: the same key rendered twice,
// or sequence-mode collisions across frames/cached fragments.

export function scanForDuplicateIds(root = document) {
  const seen = new Set()
  const dups = new Set()
  root.querySelectorAll("[id]").forEach((el) => {
    if (el.id === "") return
    if (seen.has(el.id)) dups.add(el.id)
    seen.add(el.id)
  })
  return [...dups]
}

// Installs the scanner on the page's composition events (initial load,
// Turbo loads, frame loads, morphs, stream insertions - each checked one
// frame after the event so the DOM has settled). Returns the scan
// trigger for manual use. `report` overrides the console warning.
export function installPoetryIdIntegrityCheck({ report } = {}) {
  const notify = report || ((dups) => {
    console.warn(
      `[poetry] duplicate DOM ids in the composed page: ${dups.join(", ")} - ` +
        "ARIA references resolve to the first match only. Same key: twice, " +
        "or sequence-mode ids colliding across frames/cached fragments?"
    )
  })
  const scan = () => {
    const dups = scanForDuplicateIds()
    if (dups.length > 0) notify(dups)
    return dups
  }
  const settle = () => requestAnimationFrame(scan)

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", settle, { once: true })
  } else {
    settle()
  }
  ;["turbo:load", "turbo:frame-load", "turbo:morph", "turbo:before-stream-render"].forEach((event) => {
    document.addEventListener(event, settle)
  })

  return scan
}
