# frozen_string_literal: true

module Poetry
  module Ui
    module Menubar
      # The Menubar preview matrix: the menubar-demo.tsx port (File / Edit /
      # View / Profiles - shortcuts, a Share submenu, checkbox view
      # toggles, a radio profile group), plus a disabled trigger, RTL, and
      # the server-rendered open state. Hover-slide and the cross-menu
      # arrows are runtime behavior - the browser pass drives them.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(label: "Application menu") do |bar|
            file_menu(bar)
            edit_menu(bar)
            view_menu(bar)
            profiles_menu(bar)
          end
        end

        # A disabled top-level menu: skipped by roving focus and the
        # cross-menu arrows; the bar keeps exactly one tab stop.
        def disabled_menu
          render_component(label: "Editor menu") do |bar|
            bar.with_menu do |menu|
              menu.with_trigger { "File" }
              menu.with_item { "New" }
            end
            bar.with_menu(disabled: true) do |menu|
              menu.with_trigger { "Team" }
              menu.with_item { "Invite" }
            end
            bar.with_menu do |menu|
              menu.with_trigger { "Help" }
              menu.with_item { "About" }
            end
          end
        end

        # Bar roving + the cross-menu edge moves flip under RTL; the
        # submenu side flips with them.
        def rtl
          render_component(label: "قائمة التطبيق", dir: :rtl) do |bar|
            bar.with_menu do |menu|
              menu.with_trigger { "ملف" }
              menu.with_item { "جديد" }
              menu.with_sub do |sub|
                sub.with_trigger { "مشاركة" }
                sub.with_item { "بريد إلكتروني" }
              end
            end
            bar.with_menu do |menu|
              menu.with_trigger { "تحرير" }
              menu.with_item { "تراجع" }
            end
          end
        end

        # Server-rendered open state (controllable-state: value: names the
        # open menu; the coordinator reconciles on connect).
        def open
          render_component(label: "Application menu", value: "file") do |bar|
            bar.with_menu(value: "file") do |menu|
              menu.with_trigger { "File" }
              menu.with_item(shortcut: "⌘T") { "New Tab" }
              menu.with_item { "New Window" }
            end
            bar.with_menu(value: "edit") do |menu|
              menu.with_trigger { "Edit" }
              menu.with_item { "Undo" }
            end
          end
        end

        private

        def file_menu(bar)
          bar.with_menu do |menu|
            menu.with_trigger { "File" }
            menu.with_item(shortcut: "⌘T") { "New Tab" }
            menu.with_item(shortcut: "⌘N") { "New Window" }
            menu.with_item(disabled: true) { "New Incognito Window" }
            menu.with_separator
            menu.with_sub do |sub|
              sub.with_trigger { "Share" }
              sub.with_item { "Email link" }
              sub.with_item { "Messages" }
              sub.with_item { "Notes" }
            end
            menu.with_separator
            menu.with_item(shortcut: "⌘P") { "Print..." }
          end
        end

        def edit_menu(bar)
          bar.with_menu do |menu|
            menu.with_trigger { "Edit" }
            menu.with_item(shortcut: "⌘Z") { "Undo" }
            menu.with_item(shortcut: "⇧⌘Z") { "Redo" }
            menu.with_separator
            menu.with_sub do |sub|
              sub.with_trigger { "Find" }
              sub.with_item { "Search the web" }
              sub.with_separator
              sub.with_item { "Find..." }
              sub.with_item { "Find Next" }
              sub.with_item { "Find Previous" }
            end
            menu.with_separator
            menu.with_item { "Cut" }
            menu.with_item { "Copy" }
            menu.with_item { "Paste" }
          end
        end

        def view_menu(bar)
          bar.with_menu do |menu|
            menu.with_trigger { "View" }
            menu.with_checkbox_item(close_on_select: false) { "Always Show Bookmarks Bar" }
            menu.with_checkbox_item(checked: true, close_on_select: false) { "Always Show Full URLs" }
            menu.with_separator
            menu.with_item(inset: true, shortcut: "⌘R") { "Reload" }
            menu.with_item(inset: true, disabled: true, shortcut: "⇧⌘R") { "Force Reload" }
            menu.with_separator
            menu.with_item(inset: true) { "Toggle Fullscreen" }
            menu.with_separator
            menu.with_item(inset: true) { "Hide Sidebar" }
          end
        end

        def profiles_menu(bar)
          bar.with_menu do |menu|
            menu.with_trigger { "Profiles" }
            menu.with_radio_group(value: "benoit") do |group|
              group.with_radio_item(value: "andy") { "Andy" }
              group.with_radio_item(value: "benoit") { "Benoit" }
              group.with_radio_item(value: "luis") { "Luis" }
            end
            menu.with_separator
            menu.with_item(inset: true) { "Edit..." }
            menu.with_separator
            menu.with_item(inset: true) { "Add Profile..." }
          end
        end
      end
    end
  end
end
