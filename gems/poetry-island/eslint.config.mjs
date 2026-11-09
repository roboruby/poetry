// ESLint for the controller: the recommended rules, browser globals, ES
// modules, no build step. JSDoc presence is asked of every method.
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
  { ignores: ["node_modules/**", "test/**"] }
]
