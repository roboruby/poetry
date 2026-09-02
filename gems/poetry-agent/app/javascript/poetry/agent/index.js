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
import AguiClientToolController from "@poetry/agent/agui_client_tool_controller"
import A2uiSurfaceController from "@poetry/agent/a2ui_surface_controller"
import { installVersionedReplace, installMorphStateGuard } from "@poetry/agent/stream_actions"

export { default as WebmcpController } from "@poetry/agent/webmcp_controller"
export { default as WebmcpFormController } from "@poetry/agent/webmcp_form_controller"
export { default as AguiClientToolController } from "@poetry/agent/agui_client_tool_controller"
export { default as A2uiSurfaceController } from "@poetry/agent/a2ui_surface_controller"
export * from "@poetry/agent/adapter"
export { _registrations, executeRegisteredTool } from "@poetry/agent/webmcp_controller"
export { installVersionedReplace, installMorphStateGuard, preservesLocalState } from "@poetry/agent/stream_actions"

// identifier -> controller class (the manifest introspects this).
export const controllers = {
  "poetry--agent--webmcp": WebmcpController,
  "poetry--agent--webmcp-form": WebmcpFormController,
  "poetry--agent--agui-client-tool": AguiClientToolController,
  "poetry--agent--a2ui-surface": A2uiSurfaceController
}

// Registers the runtime's controllers, installs the versioned replace
// stream action the AG-UI relay and the A2UI streams emit (when Turbo is
// present), and the morph guard that keeps an A2UI surface's local state.
export const registerPoetryAgent = (application) => {
  for (const [identifier, controller] of Object.entries(controllers)) {
    application.register(identifier, controller)
  }
  installVersionedReplace()
  installMorphStateGuard()
}
