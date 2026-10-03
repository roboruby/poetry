// The behaviors' enforcement story, modelled on events_declaration: a
// controller that sets anything up through the per-connect scope (an
// import from behaviors/, or scopeOf) must tear it down with one
// `teardown(this)` inside its own disconnect(), and a controller that
// extends another poetry controller and overrides disconnect() must call
// super.disconnect(), or the parent's scope never runs. Source scan, no
// ESLint needed.
import { describe, it, expect } from "vitest"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const DIR = path.join(
  path.dirname(fileURLToPath(import.meta.url)), "../../app/javascript/poetry/core"
)

const controllerFiles = fs.readdirSync(DIR).filter((name) => name.endsWith("_controller.js")).sort()

const usesScope = (source) =>
  /from "@poetry\/controllers\/behaviors\//.test(source) || /\bscopeOf\(/.test(source)

// The body of the controller's own disconnect(), brace-matched from its
// declaration; null when the class declares none.
const disconnectBody = (source) => {
  const match = source.match(/^  disconnect\(\) \{/m)

  if (!match) return null

  let depth = 0
  let index = match.index + match[0].length - 1

  for (; index < source.length; index += 1) {
    if (source[index] === "{") depth += 1
    if (source[index] === "}") depth -= 1
    if (depth === 0) break
  }

  return source.slice(match.index + match[0].length, index)
}

describe("behaviors teardown", () => {
  for (const file of controllerFiles) {
    const source = fs.readFileSync(path.join(DIR, file), "utf8")
    const body = disconnectBody(source)
    const extendsPoetry = /extends \w+Controller\b/.test(source) && !/extends Controller\b/.test(source)

    if (usesScope(source)) {
      it(`${file} tears its scope down in disconnect`, () => {
        expect(body, `${file} uses the scope but declares no disconnect()`).not.toBeNull()
        expect(body).toMatch(/\bteardown\(this\)/)
        expect(source).toMatch(/import \{[^}]*\bteardown\b[^}]*\} from "@poetry\/controllers\/helpers\/scope"/)
      })
    }

    if (extendsPoetry && body !== null) {
      it(`${file} overrides disconnect with a super call`, () => {
        expect(body).toMatch(/super\.disconnect\(\)/)
      })
    }
  }

  it("covers every migrated controller", () => {
    const scoped = controllerFiles.filter((file) => usesScope(fs.readFileSync(path.join(DIR, file), "utf8")))

    expect(scoped).toEqual(expect.arrayContaining([
      "combobox_controller.js", "date_field_controller.js", "deferred_controller.js", "dialog_controller.js",
      "dismissable_controller.js", "hover_card_controller.js", "menu_controller.js",
      "message_scroller_controller.js", "navigation_menu_controller.js", "popover_controller.js",
      "select_controller.js", "sidebar_controller.js", "toast_controller.js", "toaster_controller.js",
      "tooltip_controller.js", "tree_controller.js"
    ]))
  })
})
