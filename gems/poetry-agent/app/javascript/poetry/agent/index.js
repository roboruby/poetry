// @poetry/agent - the WebMCP runtime. Register beside poetry's own
// controllers:
//
//   import { Application } from "@hotwired/stimulus"
//   import { registerPoetryControllers } from "@poetry/controllers"
//   import { registerPoetryAgent } from "@poetry/agent"
//   const application = Application.start()
//   registerPoetryControllers(application)
//   registerPoetryAgent(application)
import WebmcpController from "./webmcp_controller.js"
import WebmcpFormController from "./webmcp_form_controller.js"

export { default as WebmcpController } from "./webmcp_controller.js"
export { default as WebmcpFormController } from "./webmcp_form_controller.js"
export * from "./adapter.js"
export { _registrations } from "./webmcp_controller.js"

// identifier -> controller class (the manifest introspects this).
export const controllers = {
  "poetry--agent--webmcp": WebmcpController,
  "poetry--agent--webmcp-form": WebmcpFormController
}

export const registerPoetryAgent = (application) => {
  for (const [identifier, controller] of Object.entries(controllers)) {
    application.register(identifier, controller)
  }
}
