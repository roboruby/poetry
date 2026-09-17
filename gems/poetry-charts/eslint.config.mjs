// ESLint for the controllers and DOM helpers: the recommended rules, browser
// globals, ES modules, no build step. The JSDoc tier ratchets in separately.
import js from "@eslint/js"
import globals from "globals"
import jsdoc from "eslint-plugin-jsdoc"

export default [
  js.configs.recommended,
  {
    files: ["app/javascript/**/*.js"],
    plugins: { jsdoc },
    languageOptions: { ecmaVersion: 2024, sourceType: "module", globals: { ...globals.browser } },
    rules: {
      // A leading underscore names an argument or a caught error on purpose.
      "no-unused-vars": ["error", { argsIgnorePattern: "^_", caughtErrorsIgnorePattern: "^_" }],
      // The JSDoc tier. require-jsdoc is a ratchet: test/javascript/jsdoc_floor.test.js
      // compares its count to the committed .jsdoc_floor (lower it with npm run jsdoc:floor).
      // Presence is all it asks - a one-line docstring on a trivial helper satisfies it.
      // The other rules are errors on the docstrings that exist.
      "jsdoc/require-jsdoc": ["warn", {
        require: { ClassDeclaration: true, MethodDefinition: true, FunctionDeclaration: true },
        publicOnly: false
      }],
      "jsdoc/require-param": "error",
      "jsdoc/require-returns": "error",
      "jsdoc/check-param-names": "error",
      "jsdoc/check-types": "error",
      "jsdoc/no-undefined-types": "off"
    },
    // The house spelling: Object, not object.
    settings: { jsdoc: { preferredTypes: { object: "Object", "object.<>": "Object<>", "Object.<>": "Object<>" } } }
  },
  { ignores: ["node_modules/**", "test/**", "app/javascript/poetry/charts/d3.js"] }
]
