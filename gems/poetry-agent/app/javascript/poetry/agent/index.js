// @poetry/agent - the WebMCP runtime. Register beside poetry's own
// controllers:
//
//   import { Application } from "@hotwired/stimulus"
//   import { registerPoetryControllers } from "@poetry/controllers"
//   import { registerPoetryAgent } from "@poetry/agent"
//   const application = Application.start()
//   registerPoetryControllers(application)
//   registerPoetryAgent(application)
import WebmcpController from "@poetry/agent/webmcp_controller"
import WebmcpFormController from "@poetry/agent/webmcp_form_controller"

export { default as WebmcpController } from "@poetry/agent/webmcp_controller"
export { default as WebmcpFormController } from "@poetry/agent/webmcp_form_controller"
export * from "@poetry/agent/adapter"
export { _registrations } from "@poetry/agent/webmcp_controller"

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
