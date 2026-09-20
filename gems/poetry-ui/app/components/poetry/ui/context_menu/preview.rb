# frozen_string_literal: true

module Poetry
  module Ui
    module ContextMenu
      # The ContextMenu preview matrix: the ported context-menu-demo port
      # (items + shortcuts, a submenu, checkbox items, a radio group) on a
      # right-click surface, plus inset/disabled items, the disabled
      # surface (native menu returns), RTL, the focusable-surface keyboard
      # mode, and the server-rendered open state. Long-press/pointer
      # anchoring is runtime behavior - the browser pass drives it.
      class Preview < Poetry::Core::Preview::Base
        SURFACE_CLASSES = "flex h-[150px] w-[300px] items-center justify-center rounded-md " \
                          "border border-dashed text-sm select-none"

        # The context-menu-demo port: right-click the dashed surface.
        def default
          render_component do |menu|
            menu.with_trigger(tag: :div, class: SURFACE_CLASSES) { "Right-click here" }
            menu.with_item(inset: true, shortcut: "⌘[") { "Back" }
            menu.with_item(inset: true, disabled: true, shortcut: "⌘]") { "Forward" }
            menu.with_item(inset: true, shortcut: "⌘R") { "Reload" }
            menu.with_sub do |sub|
              sub.with_trigger(inset: true) { "More Tools" }
              sub.with_item(shortcut: "⇧⌘S") { "Save Page As..." }
              sub.with_item { "Create Shortcut..." }
              sub.with_item { "Name Window..." }
              sub.with_separator
              sub.with_item { "Developer Tools" }
            end
            menu.with_separator
            menu.with_checkbox_item(checked: true, close_on_select: false, shortcut: "⌘⇧B") { "Show Bookmarks Bar" }
            menu.with_checkbox_item(checked: false, close_on_select: false) { "Show Full URLs" }
            menu.with_separator
            menu.with_radio_group(value: "pedro") do |group|
              group.with_radio_item(value: "pedro") { "Pedro Duarte" }
              group.with_radio_item(value: "colm") { "Colm Tuite" }
            end
          end
        end

        # A destructive tail + a named menu (label: -> aria-label).
        def destructive
          render_component(label: "File actions") do |menu|
            menu.with_trigger(tag: :div, class: SURFACE_CLASSES) { "quarterly-report.pdf" }
            menu.with_item { "Open" }
            menu.with_item { "Rename" }
            menu.with_separator
            menu.with_item(variant: :destructive, shortcut: "⌘⌫") { "Delete" }
          end
        end

        # disabled: true stands the handlers down - right-click here shows
        # the BROWSER-NATIVE context menu (never a dead surface).
        def disabled_surface
          render_component(disabled: true) do |menu|
            menu.with_trigger(tag: :div, class: SURFACE_CLASSES) { "Native menu here (disabled)" }
            menu.with_item { "Unreachable" }
          end
        end

        # focusable_surface: true opts the surface into the tab order with
        # the aria-keyshortcuts hint - Shift+F10 / the Menu key open it.
        def focusable_surface
          render_component(focusable_surface: true, label: "Row actions") do |menu|
            menu.with_trigger(tag: :div, class: SURFACE_CLASSES) { "Focusable row (Shift+F10)" }
            menu.with_item { "Rename" }
            menu.with_item { "Duplicate" }
          end
        end

        # The submenu side flips under RTL.
        def rtl
          render_component(dir: :rtl) do |menu|
            menu.with_trigger(tag: :div, class: SURFACE_CLASSES) { "انقر بزر الماوس الأيمن" }
            menu.with_item { "فتح" }
            menu.with_sub do |sub|
              sub.with_trigger { "المزيد" }
              sub.with_item { "استيراد" }
            end
          end
        end

        # A grouped run - the role=group wrapper between separators.
        def grouped
          render_component do |menu|
            menu.with_trigger(tag: :div, class: SURFACE_CLASSES) { "Surface" }
            menu.with_group do |group|
              group.with_item { "Cut" }
              group.with_item { "Copy" }
            end
            menu.with_separator
            menu.with_checkbox_item(checked: true, disabled: true) { "Locked toggle" }
          end
        end

        # Server-rendered open state (controllable-state: the attributes
        # are the store; positionless open anchors to the trigger rect).
        def open
          render_component(open: true) do |menu|
            menu.with_trigger(tag: :div, class: SURFACE_CLASSES) { "Surface" }
            menu.with_label { "Row" }
            menu.with_item { "Rename" }
            menu.with_separator
            menu.with_item(variant: :destructive) { "Delete" }
          end
        end
      end
    end
  end
end
