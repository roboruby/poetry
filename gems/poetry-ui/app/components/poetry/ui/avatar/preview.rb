# frozen_string_literal: true

module Poetry
  module Ui
    module Avatar
      # The Avatar preview: the initials fallback (the deterministic base
      # state), the image layer actually covering it (a data-URI png, so the
      # browser rig loads it without a network), sizes, a badge, and the
      # stacked group via the sidecar template.
      class Preview < Poetry::Core::Preview::Base
        # A 1x1 indigo png - object-cover turns it into a solid circle.
        IMAGE = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABAQMAAAAl21bKAAAAA1BMVEVjZvEU9kYI" \
                "AAAACklEQVR4nGNiAAAABgADNjd8qAAAAABJRU5ErkJggg=="

        def default
          render_component(label: "Matt Solt") { "MS" }
        end

        def with_image
          render_component(src: IMAGE, label: "Grace Hopper") { "GH" }
        end

        def small_with_badge
          render_component(size: :sm, label: "Ada Lovelace (online)") do |avatar|
            avatar.with_badge { "" }
            "AL"
          end
        end

        def large
          render_component(size: :lg, label: "Annie Easley") { "AE" }
        end

        def group
          # An explicit per-example template: a CLASS-level preview.html.erb
          # would shadow the shared default for EVERY example (the contrib
          # sidecar contract), silently replacing the other previews.
          render_with_template(template: "poetry/ui/avatar/group_preview")
        end
      end
    end
  end
end
