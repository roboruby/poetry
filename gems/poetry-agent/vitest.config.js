import { fileURLToPath } from "node:url"
import { defineConfig } from "vitest/config"

// Vitest + jsdom, the poetry-core shape. The alias mirrors the package's
// exports map so "@poetry/agent/..." specifiers resolve in tests too.
export default defineConfig({
  resolve: {
    alias: {
      "@poetry/agent": fileURLToPath(new URL("./app/javascript/poetry/agent", import.meta.url))
    }
  },
  test: {
    environment: "jsdom",
    include: ["test/javascript/**/*.test.js"]
  }
})
