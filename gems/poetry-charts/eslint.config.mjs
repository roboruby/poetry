// ESLint for the controllers and DOM helpers: the recommended rules, browser
// globals, ES modules, no build step. The JSDoc tier ratchets in separately.
import js from "@eslint/js"
import globals from "globals"

export default [
  js.configs.recommended,
  {
    files: ["app/javascript/**/*.js"],
    languageOptions: { ecmaVersion: 2024, sourceType: "module", globals: { ...globals.browser } },
    rules: {
      // A leading underscore names an argument or a caught error on purpose.
      "no-unused-vars": ["error", { argsIgnorePattern: "^_", caughtErrorsIgnorePattern: "^_" }]
    }
  },
  { ignores: ["node_modules/**", "test/**", "app/javascript/poetry/charts/d3.js"] }
]
