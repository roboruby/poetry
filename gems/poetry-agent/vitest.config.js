import { fileURLToPath } from "node:url"
import { defineConfig } from "vitest/config"

// Vitest + jsdom, the poetry-core shape. The aliases mirror the packages'
// exports maps so "@poetry/agent/..." and "@poetry/controllers/..."
// specifiers resolve in tests too (the core helpers from the sibling gem).
export default defineConfig({
  resolve: {
    alias: {
      "@poetry/agent": fileURLToPath(new URL("./app/javascript/poetry/agent", import.meta.url)),
      "@poetry/controllers": fileURLToPath(new URL("../poetry-core/app/javascript/poetry/core", import.meta.url))
    }
  },
  test: {
    environment: "jsdom",
    include: ["test/javascript/**/*.test.js"]
  }
})
