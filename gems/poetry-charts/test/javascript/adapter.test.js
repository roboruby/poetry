import { beforeEach, describe, expect, it, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryChartsControllers, registerChartAdapter, createChartJsAdapter } from "../../app/javascript/poetry/charts/index.js"

// The adapter seam: the controller hands the FROZEN spec to the
// registered engine and owns the lifecycle; the Chart.js reference
// adapter maps spec v1 to a Chart.js config with resolved colors and
// declared degradations.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const SPEC = {
  version: 1,
  type: "bar",
  data: [
    { month: "Jan", desktop: 186 },
    { month: "Feb", desktop: 305 },
  ],
  series: [{ key: "desktop", dataKey: "desktop" }],
  axes: { x: { dataKey: "month" } },
  config: { desktop: { label: "Desktop", color: "var(--chart-1)" } },
}

const markup = (engine = "fake") => `
  <div data-chart="chart-a">
    <div data-controller="poetry--charts--adapter" data-poetry--charts--adapter-engine-value="${engine}">
      <div data-poetry--charts--adapter-target="mount"></div>
      <script type="application/json" data-poetry--charts--adapter-target="spec">${JSON.stringify(SPEC)}</script>
    </div>
  </div>`

describe("poetry--charts--adapter", () => {
  let application

  beforeEach(() => {
    return async () => {
      application?.stop()
      document.body.replaceChildren()
      await nextFrame()
    }
  })

  async function boot(engine) {
    document.body.innerHTML = markup(engine)
    application = Application.start()
    registerPoetryChartsControllers(application)
    await nextFrame()
  }

  it("renders through the registered adapter and destroys on disconnect", async () => {
    const fake = { render: vi.fn().mockReturnValue({ id: 1 }), destroy: vi.fn(), degradations: ["x"] }
    registerChartAdapter("fake", fake)
    await boot("fake")

    expect(fake.render).toHaveBeenCalledTimes(1)
    const [el, spec, helpers] = fake.render.mock.calls[0]
    expect(el.dataset.poetryChartsAdapterTarget ?? el.getAttribute("data-poetry--charts--adapter-target")).toBe("mount")
    expect(spec.type).toBe("bar")
    expect(typeof helpers.resolveColor).toBe("function")

    document.querySelector("[data-controller]").remove()
    await nextFrame()
    expect(fake.destroy).toHaveBeenCalledWith({ id: 1 }, expect.anything())
  })

  it("refuses unsupported types with the adapter's allowlist", async () => {
    const fake = { render: vi.fn(), destroy: vi.fn(), supports: ["pie"] }
    registerChartAdapter("picky", fake)
    const error = vi.spyOn(console, "error").mockImplementation(() => {})
    await boot("picky")

    expect(fake.render).not.toHaveBeenCalled()
    expect(error.mock.calls[0][0]).toMatch(/does not support bar/)
    error.mockRestore()
  })

  it("reports a missing engine instead of throwing", async () => {
    const error = vi.spyOn(console, "error").mockImplementation(() => {})
    await boot("nonexistent")

    expect(error.mock.calls[0][0]).toMatch(/no adapter registered/)
    error.mockRestore()
  })
})

describe("createChartJsAdapter", () => {
  it("maps spec v1 to a Chart.js config with resolved colors", () => {
    const captured = []
    class FakeChart {
      constructor(canvas, config) {
        this.canvas = canvas
        captured.push(config)
      }

      destroy() {}
    }

    const adapter = createChartJsAdapter(FakeChart)
    const el = document.createElement("div")
    adapter.render(el, SPEC, { resolveColor: (c) => (c === "var(--chart-1)" ? "#f54900" : c) })

    const config = captured[0]
    expect(config.type).toBe("bar")
    expect(config.data.labels).toEqual(["Jan", "Feb"])
    expect(config.data.datasets[0]).toMatchObject({
      label: "Desktop",
      data: [186, 305],
      backgroundColor: "#f54900",
    })
    expect(el.querySelector("canvas")).toBeTruthy()
  })

  it("declares its degradations and its type allowlist", () => {
    const adapter = createChartJsAdapter(class {})

    expect(adapter.supports).toEqual(["area", "line", "bar", "pie", "radar"])
    expect(adapter.degradations.join(" ")).toMatch(/radial charts unsupported/)
  })

  it("area specs become filled line charts", () => {
    const captured = []
    const adapter = createChartJsAdapter(class {
      constructor(_c, config) {
        captured.push(config)
      }
    })
    adapter.render(document.createElement("div"), { ...SPEC, type: "area" }, { resolveColor: (c) => c })

    expect(captured[0].type).toBe("line")
    expect(captured[0].data.datasets[0].fill).toBe(true)
  })
})
