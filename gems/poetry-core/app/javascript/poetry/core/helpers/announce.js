// The announce SINGLETON (P5): shared screen-reader live regions - a plain
// module, not a controller. Injecting a node that IS a live region is
// unreliably announced across SR/browser pairs (the Radix Toast insight),
// so consumers keep their own nodes aria-live=off and route announcements
// through here: TWO lazily-created sr-only regions on body (polite +
// assertive), refcounted via acquire()/release() (regions removed when the
// last consumer releases; consumers: Toast, async form status, Combobox
// result counts - API changes after Toast ships are breaking, so the
// surface stays exactly this).
//
// Announcement mechanics: clear-then-set on a microtask (identical
// consecutive messages re-announce), a per-region message queue with a
// small gap between messages, textContent ONLY (live-region injection is a
// real sink - never innerHTML).
//
// Tab-visibility muting: while the tab is hidden both regions flip
// aria-live=off (muted); announcements made while hidden keep at most the
// LAST message, flushed on return (no backlog flood).

// The gap (ms) between queued messages per region - long enough for SRs to
// treat consecutive messages as separate announcements.
const QUEUE_GAP = 150

// Safari drops messages announced right after a live region is INSERTED
// (react-aria waits ~100ms post-creation; a WebKit behavior, not a spec
// timing) - a fresh region holds its queue until this warmup elapses. The
// clear-then-set rAF alone (~one frame) is shorter than Safari needs.
const REGION_WARMUP = 100

const POLITENESS = {
  polite: { role: "status", live: "polite" },
  assertive: { role: "alert", live: "assertive" }
}

let refCount = 0
let regions = null // { polite: region, assertive: region } | null
let hiddenBacklog = null // { message, politeness } - at most the LAST while hidden

const onVisibilityChange = () => {
  if (document.hidden) mute()
  else unmute()
}

// Refcounted lifecycle: a consumer acquires while it is connected and
// releases on teardown; the last release removes the regions.
export function acquire() {
  refCount += 1
  ensureRegions()
}

export function release() {
  if (refCount === 0) return

  refCount -= 1

  if (refCount === 0) teardown()
}

// The announcement surface. politeness: "polite" (default) | "assertive".
export function announce(message, politeness = "polite") {
  ensureRegions()

  const resolved = Object.hasOwn(POLITENESS, politeness) ? politeness : "polite"

  if (document.hidden) {
    hiddenBacklog = { message, politeness: resolved }
    return
  }

  enqueue(regions[resolved], message)
}

function ensureRegions() {
  // A body swap (Turbo render, test reset) can detach live regions without
  // a release - rebuild rather than announce into detached nodes.
  if (regions && !regions.polite.element.isConnected) teardown()
  if (regions) return

  regions = {
    polite: createRegion("polite"),
    assertive: createRegion("assertive")
  }

  document.addEventListener("visibilitychange", onVisibilityChange)

  if (document.hidden) mute()
}

function createRegion(politeness) {
  const element = document.createElement("div")
  const { role, live } = POLITENESS[politeness]

  element.setAttribute("data-poetry-announce-region", politeness)
  element.setAttribute("role", role)
  element.setAttribute("aria-live", live)
  element.setAttribute("aria-atomic", "true")

  // sr-only, inline (the helper cannot assume a utility class exists).
  Object.assign(element.style, {
    position: "absolute",
    width: "1px",
    height: "1px",
    padding: "0",
    margin: "-1px",
    overflow: "hidden",
    clip: "rect(0, 0, 0, 0)",
    whiteSpace: "nowrap",
    border: "0"
  })

  document.body.appendChild(element)

  const region = {
    politeness, element, queue: [], draining: false, timer: null,
    warm: false, warmupTimer: null
  }

  region.warmupTimer = window.setTimeout(() => {
    region.warmupTimer = null
    region.warm = true
    drain(region)
  }, REGION_WARMUP)

  return region
}

// Per-region queue: clear-then-set across an animation FRAME, not a
// microtask (so a message identical to the region's current text still
// re-announces), then a small gap before the next queued message. The
// frame matters twice over: a microtask lands in the SAME accessibility-
// tree flush, so (a) a freshly created region would be seen "born with
// content" - a mutation pattern ATs reliably skip - and (b) clear+set
// would coalesce into one text change, letting AT dedup swallow repeats.
// rAF pushes the set into the next frame's flush; a hidden document has
// no frames, but the visibility contract already routes those to the
// backlog before enqueue.
function enqueue(region, message) {
  region.queue.push(String(message))
  drain(region)
}

function drain(region) {
  if (!region.warm || region.draining) return

  const message = region.queue.shift()

  if (message === undefined) return

  region.draining = true
  region.element.textContent = ""

  requestAnimationFrame(() => {
    // The regions may have been torn down or muted between ticks.
    if (!regions || regions[region.politeness] !== region) return

    region.element.textContent = message
    region.timer = window.setTimeout(() => {
      region.timer = null
      region.draining = false
      drain(region)
    }, QUEUE_GAP)
  })
}

function mute() {
  if (!regions) return

  for (const region of Object.values(regions)) {
    region.element.setAttribute("aria-live", "off")
    // Muted messages are dropped - only announce() calls made while hidden
    // keep their LAST message (the backlog contract).
    region.queue.length = 0

    if (region.timer !== null) {
      window.clearTimeout(region.timer)
      region.timer = null
    }

    region.draining = false
  }
}

function unmute() {
  if (!regions) return

  for (const region of Object.values(regions)) {
    region.element.setAttribute("aria-live", POLITENESS[region.politeness].live)
  }

  if (hiddenBacklog) {
    const { message, politeness } = hiddenBacklog

    hiddenBacklog = null
    enqueue(regions[politeness], message)
  }
}

function teardown() {
  if (!regions) return

  for (const region of Object.values(regions)) {
    if (region.timer !== null) window.clearTimeout(region.timer)
    if (region.warmupTimer !== null) window.clearTimeout(region.warmupTimer)

    region.element.remove()
  }

  regions = null
  hiddenBacklog = null
  document.removeEventListener("visibilitychange", onVisibilityChange)
}
