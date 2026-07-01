# frozen_string_literal: true

module Poetry
  module Ui
    module Dialog
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component do |dialog|
            dialog.with_trigger(variant: :outline) { "Edit profile" }
            dialog.with_title { "Edit profile" }
            dialog.with_description { "Make changes and save when done." }
            dialog.with_footer do
              render(Poetry::Ui::Button::Component.new.with_content("Save changes"))
            end
            "Profile form goes here."
          end
        end

        def confirmation
          render_component(dismissible: false) do |dialog|
            dialog.with_trigger(variant: :destructive) { "Delete account" }
            dialog.with_title { "Are you absolutely sure?" }
            dialog.with_description { "This permanently deletes your account and all data." }
            dialog.with_footer do
              render(Poetry::Ui::Button::Component.new(variant: :destructive).with_content("Delete"))
            end
            ""
          end
        end
      end
    end
  end
end
