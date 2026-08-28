# frozen_string_literal: true

module Poetry
  module Ui
    module Command
      # The CommandDialog preview - the trigger-opened palette (the modal
      # behaviors live in the browser pass; previews cover markup).
      class DialogPreview < Poetry::Core::Preview::Base
        def default
          render_component do |palette|
            palette.with_trigger(variant: :outline) { "Open command palette" }
            palette.with_group(heading: "Suggestions") do |group|
              group.with_item(value: "calendar") { "Calendar" }
              group.with_item(value: "emoji") { "Search Emoji" }
            end
            palette.with_group(heading: "Settings") do |group|
              group.with_item(value: "profile", shortcut: "⌘P") { "Profile" }
            end
          end
        end

        def close_button
          render_component(show_close_button: true) do |palette|
            palette.with_trigger(variant: :outline) { "Open with a close button" }
            palette.with_item(value: "calendar") { "Calendar" }
            palette.with_item(value: "emoji") { "Search Emoji" }
          end
        end

        def with_hotkey
          render_component(hotkey: "meta+k") do |palette|
            palette.with_trigger(variant: :outline) { "⌘K" }
            palette.with_item(value: "calendar") { "Calendar" }
          end
        end
      end
    end
  end
end
