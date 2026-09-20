# frozen_string_literal: true

module Poetry
  module Ui
    module AlertDialog
      class Preview < Poetry::Core::Preview::Base
        # The canonical recipe: a destructive confirmation. Backdrop clicks
        # never dismiss it; Esc still cancels (source-exact posture).
        def destructive_confirm
          render_component do |dialog|
            dialog.with_trigger(variant: :destructive) { "Delete account" }
            dialog.with_title { "Are you absolutely sure?" }
            dialog.with_description { "This permanently deletes your account and all of its data." }
            dialog.with_cancel { "Cancel" }
            dialog.with_action(variant: :destructive) { "Delete account" }
            ""
          end
        end

        # The media well above the title (an icon), the header's third row.
        def with_media
          render_component do |dialog|
            dialog.with_trigger(variant: :outline) { "Archive project" }
            dialog.with_media { embed(Icon::Component.new(name: :archive)) }
            dialog.with_title { "Archive this project?" }
            dialog.with_description { "Archived projects are read-only until restored." }
            dialog.with_cancel { "Keep it" }
            dialog.with_action { "Archive" }
            ""
          end
        end

        # Initial focus lands on Cancel (autofocus - APG: focus the
        # least-destructive action); the compact sm size for quick confirms.
        def cancel_autofocus
          render_component(size: :sm) do |dialog|
            dialog.with_trigger(variant: :outline) { "Publish changes" }
            dialog.with_title { "Publish these changes?" }
            dialog.with_description { "Your edits go live immediately." }
            dialog.with_cancel { "Cancel" }
            dialog.with_action { "Publish" }
            ""
          end
        end
      end
    end
  end
end
