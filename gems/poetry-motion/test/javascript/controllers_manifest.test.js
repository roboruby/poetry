import { describe, expect, it } from "vitest"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

import AnimatedListController from "../../app/javascript/poetry/motion/animated_list_controller.js"
import ConfettiController from "../../app/javascript/poetry/motion/confetti_controller.js"
import DockController from "../../app/javascript/poetry/motion/dock_controller.js"
import GlobeController from "../../app/javascript/poetry/motion/globe_controller.js"
import LayoutGroupController from "../../app/javascript/poetry/motion/layout_group_controller.js"
import MagneticController from "../../app/javascript/poetry/motion/magnetic_controller.js"
import ParallaxController from "../../app/javascript/poetry/motion/parallax_controller.js"
import ParticlesController from "../../app/javascript/poetry/motion/particles_controller.js"
import ScrambleController from "../../app/javascript/poetry/motion/scramble_controller.js"
import ScrollProgressController from "../../app/javascript/poetry/motion/scroll_progress_controller.js"
import SpotlightCardController from "../../app/javascript/poetry/motion/spotlight_card_controller.js"
import TypewriterController from "../../app/javascript/poetry/motion/typewriter_controller.js"
import WordRotateController from "../../app/javascript/poetry/motion/word_rotate_controller.js"
import MarqueeController from "../../app/javascript/poetry/motion/marquee_controller.js"
import TextRevealController from "../../app/javascript/poetry/motion/text_reveal_controller.js"
import NumberTickerController from "../../app/javascript/poetry/motion/number_ticker_controller.js"
import TiltCardController from "../../app/javascript/poetry/motion/tilt_card_controller.js"
import { mergedDocs, withDocs } from "./support/controller_docs.js"

// The controllers manifest, self-drift-gating (the poetry-charts pattern):
// targets, values, public methods and events introspected from the live
// controller classes and committed; use_stimulus declarations validate
// against it at class load. Regenerate with `npm run manifest`.

const ROOT = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))))
const MANIFEST_PATH = path.join(ROOT, "config", "controllers_manifest.json")

const CONTROLLERS = {
  "poetry--motion--animated-list": AnimatedListController,
  "poetry--motion--confetti": ConfettiController,
  "poetry--motion--dock": DockController,
  "poetry--motion--globe": GlobeController,
  "poetry--motion--layout-group": LayoutGroupController,
  "poetry--motion--magnetic": MagneticController,
  "poetry--motion--marquee": MarqueeController,
  "poetry--motion--number-ticker": NumberTickerController,
  "poetry--motion--parallax": ParallaxController,
  "poetry--motion--particles": ParticlesController,
  "poetry--motion--scramble": ScrambleController,
  "poetry--motion--scroll-progress": ScrollProgressController,
  "poetry--motion--spotlight-card": SpotlightCardController,
  "poetry--motion--text-reveal": TextRevealController,
  "poetry--motion--tilt-card": TiltCardController,
  "poetry--motion--typewriter": TypewriterController,
  "poetry--motion--word-rotate": WordRotateController,
}

const publicMethods = (klass) =>
  Object.getOwnPropertyNames(klass.prototype).filter((name) => name !== "constructor" && !name.startsWith("#")).sort()

const serializeValues = (values = {}) =>
  Object.fromEntries(Object.entries(values).map(([name, definition]) => {
    const expanded = typeof definition === "function" ? { type: definition } : definition
    return [name, {
      type: expanded.type.name,
      ...(Object.hasOwn(expanded, "default") ? { default: expanded.default } : {})
    }]
  }))

const fileFor = (identifier) =>
  path.join(ROOT, "app/javascript/poetry/motion", `${identifier.replace("poetry--motion--", "").replace(/-/g, "_")}_controller.js`)

const introspect = () => Object.fromEntries(
  Object.entries(CONTROLLERS).map(([identifier, klass]) => [
    identifier,
    withDocs({
      targets: [...(klass.targets ?? [])].sort(),
      values: serializeValues(klass.values),
      methods: publicMethods(klass),
      events: [...(klass.events ?? [])].sort(),
    }, mergedDocs([fileFor(identifier)])),
  ])
)

describe("controllers manifest", () => {
  it("matches the committed config/controllers_manifest.json", () => {
    const live = introspect()

    if (process.env.MANIFEST_WRITE === "1") {
      fs.writeFileSync(MANIFEST_PATH, `${JSON.stringify(live, null, 2)}\n`)
      return
    }

    expect(live).toEqual(JSON.parse(fs.readFileSync(MANIFEST_PATH, "utf8")))
  })

  it("every controller is registered by the package entrypoint", () => {
    const index = fs.readFileSync(path.join(ROOT, "app/javascript/poetry/motion/index.js"), "utf8")
    for (const identifier of Object.keys(CONTROLLERS)) expect(index).toContain(`"${identifier}"`)
  })
})
