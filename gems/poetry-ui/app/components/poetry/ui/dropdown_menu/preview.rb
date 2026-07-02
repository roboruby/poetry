# frozen_string_literal: true

module Poetry
  module Ui
    module DropdownMenu
      # The DropdownMenu preview matrix: the shadcn demo composition plus
      # both item variants, both toggle kinds, inset, disabled, a 2-deep
      # sub, RTL, and the server-rendered open state.
      class Preview < Poetry::Core::Preview::Base
        # The dropdown-menu-demo port: Button trigger, label, grouped items
        # with shortcuts, a submenu, a disabled item, a destructive tail.
        def default
          render_component(align: :start) do |menu|
            menu.with_trigger(variant: :outline) { "Open" }
            menu.with_label { "My Account" }
            menu.with_group do |group|
              group.with_item(shortcut: "⇧⌘P") { "Profile" }
              group.with_item(shortcut: "⌘B") { "Billing" }
              group.with_item(shortcut: "⌘S") { "Settings" }
            end
            menu.with_separator
            menu.with_sub do |sub|
              sub.with_trigger { "Invite users" }
              sub.with_item { "Email" }
              sub.with_item { "Message" }
              sub.with_sub do |nested|
                nested.with_trigger { "More..." }
                nested.with_item { "Import from CSV" }
              end
            end
            menu.with_separator
            menu.with_item(disabled: true) { "API" }
            menu.with_item(variant: :destructive, shortcut: "⇧⌘Q") { "Log out" }
          end
        end

        # dropdown-menu-checkboxes parity: toggles keep the menu open.
        def checkboxes
          render_component(align: :start) do |menu|
            menu.with_trigger(variant: :outline) { "View" }
            menu.with_label { "Appearance" }
            menu.with_separator
            menu.with_checkbox_item(checked: true, close_on_select: false) { "Status Bar" }
            menu.with_checkbox_item(checked: false, close_on_select: false, disabled: true) { "Activity Bar" }
            menu.with_checkbox_item(checked: false, close_on_select: false) { "Panel" }
          end
        end

        # dropdown-menu-radio-group parity: one checked value per group.
        def radio_group
          render_component(align: :start) do |menu|
            menu.with_trigger(variant: :outline) { "Panel Position" }
            menu.with_label { "Panel Position" }
            menu.with_separator
            menu.with_radio_group(value: "bottom") do |group|
              group.with_radio_item(value: "top") { "Top" }
              group.with_radio_item(value: "bottom") { "Bottom" }
              group.with_radio_item(value: "right") { "Right" }
            end
          end
        end

        # inset aligns flush items with the checkbox/radio gutter.
        def inset_and_disabled
          render_component do |menu|
            menu.with_trigger(variant: :outline) { "Edit" }
            menu.with_label(inset: true) { "Actions" }
            menu.with_item(inset: true) { "Undo" }
            menu.with_item(inset: true, disabled: true) { "Redo" }
            menu.with_separator
            menu.with_checkbox_item(checked: true, close_on_select: false) { "Autosave" }
          end
        end

        # The submenu side flips under RTL (chevron mirrors via ml-auto).
        def rtl
          render_component(dir: :rtl) do |menu|
            menu.with_trigger(variant: :outline) { "فتح" }
            menu.with_item { "الملف الشخصي" }
            menu.with_sub do |sub|
              sub.with_trigger { "المزيد" }
              sub.with_item { "استيراد" }
            end
          end
        end

        # Server-rendered open state (controllable-state: the attributes
        # are the store; the controller reconciles on connect).
        def open
          render_component(open: true, align: :start) do |menu|
            menu.with_trigger(variant: :outline) { "Open" }
            menu.with_label { "My Account" }
            menu.with_item { "Profile" }
            menu.with_separator
            menu.with_item(variant: :destructive) { "Delete" }
          end
        end
      end
    end
  end
end
