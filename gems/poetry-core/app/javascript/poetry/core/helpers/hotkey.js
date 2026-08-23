// The hotkey descriptor grammar, extracted from the dialog controller so
// any surface can speak it (the generic hotkey controller, future
// data-hotkey affordances). "meta+k" / "ctrl+shift+p": '+'-separated
// modifiers plus one final key token, matched exactly - unlisted modifiers
// must be UP, so plain typing never triggers. "meta" matches metaKey OR
// ctrlKey (⌘K on mac, ^K elsewhere - the command-palette convention).
export function matchesHotkey(event, descriptor) {
  const tokens = descriptor.toLowerCase().split("+").map((token) => token.trim())
  const key = tokens.pop()

  if ((event.key ?? "").toLowerCase() !== key) return false

  const meta = tokens.includes("meta") ? (event.metaKey || event.ctrlKey) : true
  const ctrl = tokens.includes("ctrl") ? event.ctrlKey : true
  const shift = tokens.includes("shift") === event.shiftKey
  const alt = tokens.includes("alt") === event.altKey
  const noStray = tokens.includes("meta") || tokens.includes("ctrl") ||
    (!event.metaKey && !event.ctrlKey)

  return meta && ctrl && shift && alt && noStray
}

// True when the event originates in a text-editing context - unmodified
// single-key shortcuts ("/", "?") must stay inert while the user types
// (the standard hotkey ignore list: form fields and contenteditable).
export function isEditingTarget(event) {
  const target = event.composedPath?.()[0] ?? event.target
  if (!target || !(target instanceof Element)) return false

  return Boolean(["INPUT", "TEXTAREA", "SELECT"].includes(target.tagName) || target.isContentEditable)
}
