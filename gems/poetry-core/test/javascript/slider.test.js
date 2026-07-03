import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--slider JS-unit: the math core (snap/clamp/neighbor-gap with
// decimal precision), the APG keyboard map under orientation x RTL x
// inverted, nearest-thumb pointer capture with absolute projection (stubbed
// track geometry - jsdom has none), dynamic per-thumb aria bounds, the
// change-per-mutation / commit-per-gesture split, and hidden-input sync
// with native events on commit.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const el = (id) => document.getElementById(id)

const press = (element, key, options = {}) =>
  element.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true, ...options }))

// jsdom has no PointerEvent - MouseEvent with pointer types carries the
// same clientX/clientY the controller reads.
const pointer = (element, type, { x = 0, y = 0 } = {}) =>
  element.dispatchEvent(new MouseEvent(type, { bubbles: true, cancelable: true, clientX: x, clientY: y }))

const RECT = { left: 0, right: 100, top: 0, bottom: 100, width: 100, height: 100 }

const markup = ({
  values = [50], min = 0, max = 100, step = 1, gap = 0,
  orientation = "horizontal", inverted = false, dir = null, disabled = false, name = "volume"
} = {}) => `
  <div id="shell" ${dir ? `dir="${dir}"` : ""}>
    <div id="slider" data-slot="slider" data-component="slider"
         data-controller="poetry--core--slider"
         data-poetry--core--slider-min-value="${min}"
         data-poetry--core--slider-max-value="${max}"
         data-poetry--core--slider-step-value="${step}"
         data-poetry--core--slider-value-value="${JSON.stringify(values).replace(/"/g, "&quot;")}"
         data-poetry--core--slider-min-steps-between-thumbs-value="${gap}"
         data-poetry--core--slider-orientation-value="${orientation}"
         data-poetry--core--slider-inverted-value="${inverted}"
         data-orientation="${orientation}" ${disabled ? "data-disabled" : ""}
         data-action="pointerdown->poetry--core--slider#pointerdown">
      <div id="track" data-slot="slider-track" data-poetry--core--slider-target="track">
        <div id="range" data-slot="slider-range" data-poetry--core--slider-target="range"></div>
      </div>
      ${values.map((v, i) => `
        <div id="thumb-${i}" data-slot="slider-thumb" role="slider" tabindex="${disabled ? -1 : 0}"
             aria-valuemin="${min}" aria-valuemax="${max}" aria-valuenow="${v}"
             aria-orientation="${orientation}" aria-label="Thumb ${i}"
             data-poetry--core--slider-target="thumb"
             data-action="keydown->poetry--core--slider#keydown"></div>
        <input type="hidden" name="${name}${values.length > 1 ? "[]" : ""}" value="${v}"
               data-poetry--core--slider-target="input">`).join("")}
    </div>
  </div>`

async function mount(options = {}) {
  document.body.innerHTML = markup(options)
  el("track").getBoundingClientRect = () => ({ ...RECT })
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

const now = (i = 0) => el(`thumb-${i}`).getAttribute("aria-valuenow")
const inputs = () => Array.from(document.querySelectorAll("input[type=hidden]")).map((input) => input.value)

describe("poetry--core--slider", () => {
  let application

  beforeEach(async () => {
    application = await mount()
    return async () => {
      document.body.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  describe("keyboard math", () => {
    it("arrows step +-1 step; Up/Right increment, Down/Left decrement", () => {
      press(el("thumb-0"), "ArrowRight")
      expect(now()).toBe("51")

      press(el("thumb-0"), "ArrowUp")
      expect(now()).toBe("52")

      press(el("thumb-0"), "ArrowLeft")
      press(el("thumb-0"), "ArrowDown")
      expect(now()).toBe("50")
    })

    it("Shift+Arrow and PageUp/PageDown step x10; Home/End hit min/max", () => {
      press(el("thumb-0"), "ArrowRight", { shiftKey: true })
      expect(now()).toBe("60")

      press(el("thumb-0"), "PageDown")
      expect(now()).toBe("50")

      press(el("thumb-0"), "PageUp")
      expect(now()).toBe("60")

      press(el("thumb-0"), "End")
      expect(now()).toBe("100")

      press(el("thumb-0"), "Home")
      expect(now()).toBe("0")
    })

    it("clamps at min/max and handled keys preventDefault", () => {
      press(el("thumb-0"), "End")
      const handled = press(el("thumb-0"), "ArrowRight") // dispatchEvent false = preventDefault'ed

      expect(handled).toBe(false)
      expect(now()).toBe("100")

      press(el("thumb-0"), "Home")
      press(el("thumb-0"), "ArrowLeft")
      expect(now()).toBe("0")
    })

    it("horizontal RTL swaps Left/Right ONLY (Up/Down unchanged)", async () => {
      application.stop()
      application = await mount({ dir: "rtl" })

      press(el("thumb-0"), "ArrowLeft") // rtl: Left increments
      expect(now()).toBe("51")

      press(el("thumb-0"), "ArrowRight")
      expect(now()).toBe("50")

      press(el("thumb-0"), "ArrowUp") // vertical pair untouched
      expect(now()).toBe("51")
    })

    it("inverted flips the increments; rtl + inverted cancels back to ltr math", async () => {
      application.stop()
      application = await mount({ inverted: true })

      press(el("thumb-0"), "ArrowRight")
      expect(now()).toBe("49")

      press(el("thumb-0"), "PageUp")
      expect(now()).toBe("39")

      application.stop()
      application = await mount({ inverted: true, dir: "rtl" })

      press(el("thumb-0"), "ArrowRight") // both flips cancel
      expect(now()).toBe("51")
    })

    it("decimal steps land on the exact grid (0.1 + 0.2 is 0.3)", async () => {
      application.stop()
      application = await mount({ values: [0.2], min: 0, max: 1, step: 0.1 })

      press(el("thumb-0"), "ArrowRight")
      expect(now()).toBe("0.3")

      press(el("thumb-0"), "ArrowRight")
      expect(now()).toBe("0.4")
    })
  })

  describe("range mode (two thumbs + min gap)", () => {
    beforeEach(async () => {
      application.stop()
      application = await mount({ values: [20, 80], gap: 2, name: "price" })
    })

    it("thumbs clamp at neighbor +- the gap and never cross", () => {
      press(el("thumb-0"), "End") // low thumb's effective max = 80 - 2
      expect(now(0)).toBe("78")

      press(el("thumb-1"), "Home") // high thumb's effective min = 78 + 2
      expect(now(1)).toBe("80")
    })

    it("aria-valuemin/max are DYNAMIC: a neighbor's move rewrites the other thumb's bounds", () => {
      expect(el("thumb-0").getAttribute("aria-valuemax")).toBe("78") // 80 - gap
      expect(el("thumb-1").getAttribute("aria-valuemin")).toBe("22") // 20 + gap

      press(el("thumb-0"), "ArrowRight", { shiftKey: true }) // low: 20 -> 30

      expect(now(0)).toBe("30")
      expect(el("thumb-1").getAttribute("aria-valuemin")).toBe("32") // rewritten
      expect(el("thumb-0").getAttribute("aria-valuemax")).toBe("78")
    })

    it("geometry vars track both thumbs", () => {
      expect(el("slider").style.getPropertyValue("--slider-start")).toBe("20%")
      expect(el("slider").style.getPropertyValue("--slider-end")).toBe("80%")

      press(el("thumb-1"), "ArrowLeft", { shiftKey: true })
      expect(el("slider").style.getPropertyValue("--slider-end")).toBe("70%")
    })
  })

  describe("pointer path (stubbed geometry: 100px track at origin)", () => {
    it("pointerdown jumps the nearest thumb to the pointer value, focuses it, and drags absolutely", () => {
      pointer(el("slider"), "pointerdown", { x: 30 })

      expect(now()).toBe("30")
      expect(document.activeElement).toBe(el("thumb-0"))
      expect(el("slider").hasAttribute("data-dragging")).toBe(true)

      pointer(window, "pointermove", { x: 62 })
      expect(now()).toBe("62")

      pointer(window, "pointermove", { x: 130 }) // past the track: clamps to max
      expect(now()).toBe("100")

      pointer(window, "pointerup", {})
      expect(el("slider").hasAttribute("data-dragging")).toBe(false)
    })

    it("range: the nearest thumb wins; a tie resolves to the LATER index; overshoot clamps, never swaps", async () => {
      application.stop()
      application = await mount({ values: [40, 60], name: "price" })

      pointer(el("slider"), "pointerdown", { x: 50 }) // equidistant tie -> the later thumb
      expect(document.activeElement).toBe(el("thumb-1"))
      expect(now(1)).toBe("50")

      pointer(window, "pointermove", { x: 10 }) // overshoot past the low thumb
      expect(now(1)).toBe("40") // clamped at the neighbor, no swap
      expect(now(0)).toBe("40")

      pointer(window, "pointerup", {})
    })

    it("vertical grows bottom-up", async () => {
      application.stop()
      application = await mount({ orientation: "vertical" })

      pointer(el("slider"), "pointerdown", { y: 25 }) // 25px from the top of a 100px track
      expect(now()).toBe("75")

      pointer(window, "pointerup", {})
    })

    it("horizontal RTL flips the pointer projection", async () => {
      application.stop()
      application = await mount({ dir: "rtl" })

      pointer(el("slider"), "pointerdown", { x: 30 })
      expect(now()).toBe("70")

      pointer(window, "pointerup", {})
    })
  })

  describe("events + hidden inputs", () => {
    it("change fires per mutation; commit once per pointer gesture; inputs sync + native change on commit only", () => {
      const changes = []
      const commits = []
      const nativeChanges = []
      el("slider").addEventListener("poetry:slider:change", (event) => changes.push(event.detail))
      el("slider").addEventListener("poetry:slider:commit", (event) => commits.push(event.detail))
      el("slider").addEventListener("change", (event) => {
        if (event.target instanceof HTMLInputElement) nativeChanges.push(event.target.value)
      })

      pointer(el("slider"), "pointerdown", { x: 30 })
      pointer(window, "pointermove", { x: 40 })
      pointer(window, "pointermove", { x: 45 })

      expect(changes).toEqual([
        { value: [30], index: 0 },
        { value: [40], index: 0 },
        { value: [45], index: 0 }
      ])
      expect(commits).toEqual([])
      expect(inputs()).toEqual(["50"]) // not yet committed

      pointer(window, "pointerup", {})

      expect(commits).toEqual([{ value: [45] }])
      expect(inputs()).toEqual(["45"])
      expect(nativeChanges).toEqual(["45"])
    })

    it("keyboard commits per keydown (Radix-exact) and syncs the input", () => {
      const commits = []
      el("slider").addEventListener("poetry:slider:commit", (event) => commits.push(event.detail))

      press(el("thumb-0"), "ArrowRight")
      press(el("thumb-0"), "ArrowRight")

      expect(commits).toEqual([{ value: [51] }, { value: [52] }])
      expect(inputs()).toEqual(["52"])
    })

    it("a clamped no-op keystroke fires neither change nor commit", () => {
      const events = []
      el("slider").addEventListener("poetry:slider:change", () => events.push("change"))
      el("slider").addEventListener("poetry:slider:commit", () => events.push("commit"))

      press(el("thumb-0"), "Home")
      events.length = 0

      press(el("thumb-0"), "ArrowLeft") // already at min

      expect(events).toEqual([])
    })
  })

  it("setValue is the programmatic surface (snapped, clamped, committed)", async () => {
    const controller = application.getControllerForElementAndIdentifier(el("slider"), "poetry--core--slider")

    controller.setValue([77.4])
    expect(now()).toBe("77")
    expect(inputs()).toEqual(["77"])

    controller.setValue([1, 2]) // wrong thumb count rejected
    expect(now()).toBe("77")
  })

  it("disabled guard: keyboard and pointer are no-ops", async () => {
    application.stop()
    application = await mount({ disabled: true })

    press(el("thumb-0"), "ArrowRight")
    pointer(el("slider"), "pointerdown", { x: 10 })

    expect(now()).toBe("50")
    expect(el("slider").hasAttribute("data-dragging")).toBe(false)
  })

  it("reconcile-on-connect projects the server value into aria + vars + inputs", async () => {
    application.stop()
    application = await mount({ values: [25] })

    expect(now()).toBe("25")
    expect(el("slider").style.getPropertyValue("--slider-end")).toBe("25%")
    expect(el("thumb-0").getAttribute("aria-valuemin")).toBe("0")
    expect(el("thumb-0").getAttribute("aria-valuemax")).toBe("100")
  })
})
