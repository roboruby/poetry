// @poetry/controllers - poetry's Stimulus controllers + DOM helpers, one
// source shipped over two channels: importmap-first (the engine
// pins this tree; zero build) and this same tree as the npm package for
// esbuild / Vite / jsbundling hosts. Never requires a bundler.

import { registerBridgeEvents } from "@poetry/controllers/helpers/portal"
import { guardPoetryRegistration } from "@poetry/controllers/helpers/registration_guard"
import StateController from "@poetry/controllers/state_controller"
import DialogController from "@poetry/controllers/dialog_controller"
import MessageScrollerController from "@poetry/controllers/message_scroller_controller"
import AccordionController from "@poetry/controllers/accordion_controller"
import AutocompleteController from "@poetry/controllers/autocomplete_controller"
import SearchFieldController from "@poetry/controllers/search_field_controller"
import ClipboardTextController from "@poetry/controllers/clipboard_text_controller"
import SensitiveInputController from "@poetry/controllers/sensitive_input_controller"
import RovingFocusController from "@poetry/controllers/roving_focus_controller"
import FocusScopeController from "@poetry/controllers/focus_scope_controller"
import DismissableController from "@poetry/controllers/dismissable_controller"
import PopperController from "@poetry/controllers/popper_controller"
import MenuController from "@poetry/controllers/menu_controller"
import ContextMenuController from "@poetry/controllers/context_menu_controller"
import DateFieldController from "@poetry/controllers/date_field_controller"
import FileInputController from "@poetry/controllers/file_input_controller"
import MaskController from "@poetry/controllers/mask_controller"
import MenubarController from "@poetry/controllers/menubar_controller"
import PopoverController from "@poetry/controllers/popover_controller"
import TreeController from "@poetry/controllers/tree_controller"
import TooltipController from "@poetry/controllers/tooltip_controller"
import HoverCardController from "@poetry/controllers/hover_card_controller"
import ToastController from "@poetry/controllers/toast_controller"
import ToastTriggerController from "@poetry/controllers/toast_trigger_controller"
import ToasterController from "@poetry/controllers/toaster_controller"
import CheckedController from "@poetry/controllers/checked_controller"
import CheckboxGroupController from "@poetry/controllers/checkbox_group_controller"
import PressedController from "@poetry/controllers/pressed_controller"
import ToggleGroupController from "@poetry/controllers/toggle_group_controller"
import QuestionnaireController from "@poetry/controllers/questionnaire_controller"
import RadioGroupController from "@poetry/controllers/radio_group_controller"
import SliderController from "@poetry/controllers/slider_controller"
import OtpController from "@poetry/controllers/otp_controller"
import SelectController from "@poetry/controllers/select_controller"
import CommandController from "@poetry/controllers/command_controller"
import ComboboxController from "@poetry/controllers/combobox_controller"
import TagGroupController from "@poetry/controllers/tag_group_controller"
import TableSelectionController from "@poetry/controllers/table_selection_controller"
import ActionBarController from "@poetry/controllers/action_bar_controller"
import TabsController from "@poetry/controllers/tabs_controller"
import DrawerController from "@poetry/controllers/drawer_controller"
import SheetController from "@poetry/controllers/sheet_controller"
import CarouselController from "@poetry/controllers/carousel_controller"
import ResizableController from "@poetry/controllers/resizable_controller"
import NumberFieldController from "@poetry/controllers/number_field_controller"
import NavigationMenuController from "@poetry/controllers/navigation_menu_controller"
import SidebarController from "@poetry/controllers/sidebar_controller"
import CalendarController from "@poetry/controllers/calendar_controller"
import DatePickerController from "@poetry/controllers/date_picker_controller"
import DeferredController from "@poetry/controllers/deferred_controller"
import HotkeyController from "@poetry/controllers/hotkey_controller"
import OptimisticFormController from "@poetry/controllers/optimistic_form_controller"

export { default as StateController } from "@poetry/controllers/state_controller"
export { default as DialogController } from "@poetry/controllers/dialog_controller"
export { default as MessageScrollerController } from "@poetry/controllers/message_scroller_controller"
export { default as AccordionController } from "@poetry/controllers/accordion_controller"
export { default as AutocompleteController } from "@poetry/controllers/autocomplete_controller"
export { default as SearchFieldController } from "@poetry/controllers/search_field_controller"
export { default as ClipboardTextController } from "@poetry/controllers/clipboard_text_controller"
export { default as SensitiveInputController } from "@poetry/controllers/sensitive_input_controller"
export { default as RovingFocusController } from "@poetry/controllers/roving_focus_controller"
export { default as FocusScopeController } from "@poetry/controllers/focus_scope_controller"
export { default as DismissableController } from "@poetry/controllers/dismissable_controller"
export { default as PopperController } from "@poetry/controllers/popper_controller"
export { default as MenuController } from "@poetry/controllers/menu_controller"
export { default as ContextMenuController } from "@poetry/controllers/context_menu_controller"
export { default as DateFieldController } from "@poetry/controllers/date_field_controller"
export { default as FileInputController } from "@poetry/controllers/file_input_controller"
export { default as MaskController } from "@poetry/controllers/mask_controller"
export { default as MenubarController } from "@poetry/controllers/menubar_controller"
export { default as PopoverController } from "@poetry/controllers/popover_controller"
export { default as TreeController } from "@poetry/controllers/tree_controller"
export { default as TooltipController } from "@poetry/controllers/tooltip_controller"
export { default as HoverCardController } from "@poetry/controllers/hover_card_controller"
export { default as ToastController } from "@poetry/controllers/toast_controller"
export { default as ToastTriggerController } from "@poetry/controllers/toast_trigger_controller"
export { default as ToasterController } from "@poetry/controllers/toaster_controller"
export { default as CheckedController } from "@poetry/controllers/checked_controller"
export { default as CheckboxGroupController } from "@poetry/controllers/checkbox_group_controller"
export { default as PressedController } from "@poetry/controllers/pressed_controller"
export { default as ToggleGroupController } from "@poetry/controllers/toggle_group_controller"
export { default as QuestionnaireController } from "@poetry/controllers/questionnaire_controller"
export { default as RadioGroupController } from "@poetry/controllers/radio_group_controller"
export { default as SliderController } from "@poetry/controllers/slider_controller"
export { default as OtpController } from "@poetry/controllers/otp_controller"
export { default as SelectController } from "@poetry/controllers/select_controller"
export { default as CommandController } from "@poetry/controllers/command_controller"
export { default as ComboboxController } from "@poetry/controllers/combobox_controller"
export { default as TagGroupController } from "@poetry/controllers/tag_group_controller"
export { default as TableSelectionController } from "@poetry/controllers/table_selection_controller"
export { default as ActionBarController } from "@poetry/controllers/action_bar_controller"
export { default as TabsController } from "@poetry/controllers/tabs_controller"
export { default as DrawerController } from "@poetry/controllers/drawer_controller"
export { default as SheetController } from "@poetry/controllers/sheet_controller"
export { default as CarouselController } from "@poetry/controllers/carousel_controller"
export { default as ResizableController } from "@poetry/controllers/resizable_controller"
export { default as NumberFieldController } from "@poetry/controllers/number_field_controller"
export { default as NavigationMenuController } from "@poetry/controllers/navigation_menu_controller"
export { default as SidebarController } from "@poetry/controllers/sidebar_controller"
export { default as CalendarController } from "@poetry/controllers/calendar_controller"
export { default as DatePickerController } from "@poetry/controllers/date_picker_controller"
export { default as DeferredController } from "@poetry/controllers/deferred_controller"
export { default as HotkeyController } from "@poetry/controllers/hotkey_controller"
export { default as OptimisticFormController } from "@poetry/controllers/optimistic_form_controller"
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
  "poetry--core--autocomplete": AutocompleteController,
  "poetry--core--search-field": SearchFieldController,
  "poetry--core--clipboard-text": ClipboardTextController,
  "poetry--core--sensitive-input": SensitiveInputController,
  "poetry--core--roving-focus": RovingFocusController,
  "poetry--core--focus-scope": FocusScopeController,
  "poetry--core--dismissable": DismissableController,
  "poetry--core--popper": PopperController,
  "poetry--core--menu": MenuController,
  "poetry--core--context-menu": ContextMenuController,
  "poetry--core--date-field": DateFieldController,
  "poetry--core--file-input": FileInputController,
  "poetry--core--mask": MaskController,
  "poetry--core--menubar": MenubarController,
  "poetry--core--popover": PopoverController,
  "poetry--core--tree": TreeController,
  "poetry--core--tooltip": TooltipController,
  "poetry--core--hover-card": HoverCardController,
  "poetry--core--toast": ToastController,
  "poetry--core--toast-trigger": ToastTriggerController,
  "poetry--core--toaster": ToasterController,
  "poetry--core--checked": CheckedController,
  "poetry--core--checkbox-group": CheckboxGroupController,
  "poetry--core--pressed": PressedController,
  "poetry--core--toggle-group": ToggleGroupController,
  "poetry--core--questionnaire": QuestionnaireController,
  "poetry--core--radio-group": RadioGroupController,
  "poetry--core--slider": SliderController,
  "poetry--core--otp": OtpController,
  "poetry--core--select": SelectController,
  "poetry--core--command": CommandController,
  "poetry--core--combobox": ComboboxController,
  "poetry--core--tag-group": TagGroupController,
  "poetry--core--table-selection": TableSelectionController,
  "poetry--core--action-bar": ActionBarController,
  "poetry--core--tabs": TabsController,
  "poetry--core--drawer": DrawerController,
  "poetry--core--sheet": SheetController,
  "poetry--core--carousel": CarouselController,
  "poetry--core--resizable": ResizableController,
  "poetry--core--number-field": NumberFieldController,
  "poetry--core--navigation-menu": NavigationMenuController,
  "poetry--core--sidebar": SidebarController,
  "poetry--core--calendar": CalendarController,
  "poetry--core--date-picker": DatePickerController,
  "poetry--core--deferred": DeferredController,
  "poetry--core--hotkey": HotkeyController,
  "poetry--core--optimistic-form": OptimisticFormController
}

// The portal event bridge stays honest against the manifest surface: the
// union of every controller's declared `static events` is the bridged
// list. Registered here so portal.js never
// imports the controllers (no cycle).
registerBridgeEvents(Object.values(controllers).flatMap((controller) => controller.events ?? []))

// The bundler-host one-liner: registers every poetry controller on the
// host's Stimulus application (importmap hosts get the same registrations
// via the engine's pins + this same call in their controllers/index.js).
export function registerPoetryControllers(application) {
  // Belt and braces with the module-scope registration above: any boot
  // path that reaches this call gets the portal bridge list even if it
  // never evaluated this module's top level (idempotent - a Set).
  registerBridgeEvents(Object.values(controllers).flatMap((controller) => controller.events ?? []))

  for (const [identifier, controller] of Object.entries(controllers)) {
    application.register(identifier, controller)
  }
  // Warn (once per identifier) about poetry controllers on the page that
  // nothing registered - the silent-inert failure nothing else surfaces.
  guardPoetryRegistration(application)
  return application
}
