import { fileURLToPath } from "node:url"
import { defineConfig } from "vitest/config"

// The JS unit-test runner: Vitest + jsdom - cheap enough to run per
// component, and the substrate the "Capybara without the browser tax"
// evaluation builds on. The alias mirrors the package's exports map so the
// same "@poetry/controllers/..." specifiers the source uses (importmap +
// npm channels) resolve in tests too.
export default defineConfig({
  resolve: {
    alias: {
      "@poetry/controllers": fileURLToPath(new URL("./app/javascript/poetry/core", import.meta.url))
    }
  },
  test: {
    environment: "jsdom",
    include: ["test/javascript/**/*.test.js"],
    setupFiles: ["test/javascript/setup.js"]
  }
})
