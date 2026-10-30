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
import McpAppHostController from "@poetry/agent/mcp_app_host_controller"
import { installVersionedReplace, installMorphStateGuard } from "@poetry/agent/stream_actions"

export { default as WebmcpController } from "@poetry/agent/webmcp_controller"
export { default as WebmcpFormController } from "@poetry/agent/webmcp_form_controller"
export { default as AguiClientToolController } from "@poetry/agent/agui_client_tool_controller"
export { default as A2uiSurfaceController } from "@poetry/agent/a2ui_surface_controller"
export { default as McpAppHostController } from "@poetry/agent/mcp_app_host_controller"
export * from "@poetry/agent/adapter"
export { _registrations, executeRegisteredTool } from "@poetry/agent/webmcp_controller"
export { installVersionedReplace, installMorphStateGuard, preservesLocalState, preservesElement } from "@poetry/agent/stream_actions"
export * from "@poetry/agent/mcp_app_host"

/**
 * identifier -> controller class (the manifest introspects this).
 */
export const controllers = {
  "poetry--agent--webmcp": WebmcpController,
  "poetry--agent--webmcp-form": WebmcpFormController,
  "poetry--agent--agui-client-tool": AguiClientToolController,
  "poetry--agent--a2ui-surface": A2uiSurfaceController,
  "poetry--agent--mcp-app-host": McpAppHostController
}

/**
 * Registers the runtime's controllers, installs the versioned replace
 * stream action the AG-UI relay and the A2UI streams emit (when Turbo is
 * present), and the morph guards that keep an A2UI surface's local state
 * and an MCP App's frame through a streamed re-render.
 *
 * @param {Object} application the Stimulus application
 */
export const registerPoetryAgent = (application) => {
  for (const [identifier, controller] of Object.entries(controllers)) {
    application.register(identifier, controller)
  }
  installVersionedReplace()
  installMorphStateGuard()
}
