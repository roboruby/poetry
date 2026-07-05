// @poetry/controllers - poetry's Stimulus controllers + DOM helpers, one
// source shipped over two channels: importmap-first (the engine
// pins this tree; zero build) and this same tree as the npm package for
// esbuild / Vite / jsbundling hosts. Never requires a bundler.

import StateController from "@poetry/controllers/state_controller"
import DialogController from "@poetry/controllers/dialog_controller"
import MessageScrollerController from "@poetry/controllers/message_scroller_controller"
import AccordionController from "@poetry/controllers/accordion_controller"
import RovingFocusController from "@poetry/controllers/roving_focus_controller"
import FocusScopeController from "@poetry/controllers/focus_scope_controller"
import DismissableController from "@poetry/controllers/dismissable_controller"
import PopperController from "@poetry/controllers/popper_controller"
import MenuController from "@poetry/controllers/menu_controller"
import ContextMenuController from "@poetry/controllers/context_menu_controller"
import MenubarController from "@poetry/controllers/menubar_controller"
import PopoverController from "@poetry/controllers/popover_controller"
import TooltipController from "@poetry/controllers/tooltip_controller"
import HoverCardController from "@poetry/controllers/hover_card_controller"
import ToastController from "@poetry/controllers/toast_controller"
import ToasterController from "@poetry/controllers/toaster_controller"
import CheckedController from "@poetry/controllers/checked_controller"
import PressedController from "@poetry/controllers/pressed_controller"
import ToggleGroupController from "@poetry/controllers/toggle_group_controller"
import RadioGroupController from "@poetry/controllers/radio_group_controller"
import SliderController from "@poetry/controllers/slider_controller"
import OtpController from "@poetry/controllers/otp_controller"
import SelectController from "@poetry/controllers/select_controller"
import CommandController from "@poetry/controllers/command_controller"
import ComboboxController from "@poetry/controllers/combobox_controller"
import TabsController from "@poetry/controllers/tabs_controller"

export { default as StateController } from "@poetry/controllers/state_controller"
export { default as DialogController } from "@poetry/controllers/dialog_controller"
export { default as MessageScrollerController } from "@poetry/controllers/message_scroller_controller"
export { default as AccordionController } from "@poetry/controllers/accordion_controller"
export { default as RovingFocusController } from "@poetry/controllers/roving_focus_controller"
export { default as FocusScopeController } from "@poetry/controllers/focus_scope_controller"
export { default as DismissableController } from "@poetry/controllers/dismissable_controller"
export { default as PopperController } from "@poetry/controllers/popper_controller"
export { default as MenuController } from "@poetry/controllers/menu_controller"
export { default as ContextMenuController } from "@poetry/controllers/context_menu_controller"
export { default as MenubarController } from "@poetry/controllers/menubar_controller"
export { default as PopoverController } from "@poetry/controllers/popover_controller"
export { default as TooltipController } from "@poetry/controllers/tooltip_controller"
export { default as HoverCardController } from "@poetry/controllers/hover_card_controller"
export { default as ToastController } from "@poetry/controllers/toast_controller"
export { default as ToasterController } from "@poetry/controllers/toaster_controller"
export { default as CheckedController } from "@poetry/controllers/checked_controller"
export { default as PressedController } from "@poetry/controllers/pressed_controller"
export { default as ToggleGroupController } from "@poetry/controllers/toggle_group_controller"
export { default as RadioGroupController } from "@poetry/controllers/radio_group_controller"
export { default as SliderController } from "@poetry/controllers/slider_controller"
export { default as OtpController } from "@poetry/controllers/otp_controller"
export { default as SelectController } from "@poetry/controllers/select_controller"
export { default as CommandController } from "@poetry/controllers/command_controller"
export { default as ComboboxController } from "@poetry/controllers/combobox_controller"
export { default as TabsController } from "@poetry/controllers/tabs_controller"
export * from "@poetry/controllers/helpers/state"
export * from "@poetry/controllers/helpers/collection"
export * from "@poetry/controllers/helpers/direction"
export * from "@poetry/controllers/helpers/tabbable"
export * from "@poetry/controllers/helpers/escape"
export * from "@poetry/controllers/helpers/focus_guards"
export * from "@poetry/controllers/helpers/presence"
export * from "@poetry/controllers/helpers/scroller_geometry"
export * from "@poetry/controllers/helpers/announce"
export * from "@poetry/controllers/helpers/typeahead"
export * from "@poetry/controllers/helpers/filter_rank"

// identifier -> controller class, for every sidecar controller poetry ships.
export const controllers = {
  "poetry--core--state": StateController,
  "poetry--core--dialog": DialogController,
  "poetry--core--message-scroller": MessageScrollerController,
  "poetry--core--accordion": AccordionController,
  "poetry--core--roving-focus": RovingFocusController,
  "poetry--core--focus-scope": FocusScopeController,
  "poetry--core--dismissable": DismissableController,
  "poetry--core--popper": PopperController,
  "poetry--core--menu": MenuController,
  "poetry--core--context-menu": ContextMenuController,
  "poetry--core--menubar": MenubarController,
  "poetry--core--popover": PopoverController,
  "poetry--core--tooltip": TooltipController,
  "poetry--core--hover-card": HoverCardController,
  "poetry--core--toast": ToastController,
  "poetry--core--toaster": ToasterController,
  "poetry--core--checked": CheckedController,
  "poetry--core--pressed": PressedController,
  "poetry--core--toggle-group": ToggleGroupController,
  "poetry--core--radio-group": RadioGroupController,
  "poetry--core--slider": SliderController,
  "poetry--core--otp": OtpController,
  "poetry--core--select": SelectController,
  "poetry--core--command": CommandController,
  "poetry--core--combobox": ComboboxController,
  "poetry--core--tabs": TabsController
}

// The bundler-host one-liner: registers every poetry controller on the
// host's Stimulus application (importmap hosts get the same registrations
// via the engine's pins + this same call in their controllers/index.js).
export function registerPoetryControllers(application) {
  for (const [identifier, controller] of Object.entries(controllers)) {
    application.register(identifier, controller)
  }
  return application
}
