# frozen_string_literal: true

module Poetry
  module Ui
    module Attachment
      # The Attachment preview matrix - every lifecycle state + both
      # orientations (the visual states are pure CSS on data-upload-state).
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component do |attachment|
            attachment.with_media { icon(:file) }
            attachment.with_title { "quarterly-report.pdf" }
            attachment.with_description { "1.2 MB" }
          end
        end

        def uploading
          render_component(state: :uploading) do |attachment|
            attachment.with_media { icon(:file) }
            attachment.with_title { "photo.png" }
            attachment.with_description { "uploading…" }
          end
        end

        def error
          render_component(state: :error) do |attachment|
            attachment.with_media { icon(:"circle-alert") }
            attachment.with_title { "notes.txt" }
            attachment.with_description { "Too large (max 10 MB)" }
          end
        end

        def idle_dropzone
          render_component(state: :idle) do |attachment|
            attachment.with_media { icon(:plus) }
            attachment.with_title { "Add a file" }
          end
        end

        def vertical_with_actions
          render_component(orientation: :vertical) do |attachment|
            attachment.with_media(variant: :image) { icon(:image) }
            attachment.with_title { "screenshot.png" }
            attachment.with_action(label: "Remove") { icon(:x) }
          end
        end

        private

        def icon(name)
          embed(Icon::Component.new(name: name))
        end
      end
    end
  end
end
