# frozen_string_literal: true

module Poetry
  module Ui
    module Avatar
      # The Avatar preview: the initials fallback (the deterministic base
      # state), the image layer actually covering it (a data-URI svg, so the
      # browser rig loads it without a network), sizes, a badge, and the
      # stacked group via the sidecar template.
      class Preview < Poetry::Core::Preview::Base
        # A gradient + head-and-shoulders silhouette - unlike the 1x1 solid
        # pixel it replaced, this is visibly an image, so the screenshot can
        # tell "image loaded" apart from a tinted fallback.
        IMAGE = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA2NC" \
                "A2NCI+PGRlZnM+PGxpbmVhckdyYWRpZW50IGlkPSJnIiB4MT0iMCIgeTE9IjAiIHgyPSIxIiB5Mj0iMSI+PHN0b3Agb2Zmc2V0PS" \
                "IwIiBzdG9wLWNvbG9yPSIjNjM2NmYxIi8+PHN0b3Agb2Zmc2V0PSIuNTUiIHN0b3AtY29sb3I9IiM4YjVjZjYiLz48c3RvcCBvZm" \
                "ZzZXQ9IjEiIHN0b3AtY29sb3I9IiNlYzQ4OTkiLz48L2xpbmVhckdyYWRpZW50PjwvZGVmcz48cmVjdCB3aWR0aD0iNjQiIGhlaW" \
                "dodD0iNjQiIGZpbGw9InVybCgjZykiLz48Y2lyY2xlIGN4PSIzMiIgY3k9IjI1IiByPSIxMCIgZmlsbD0iI2ZmZiIgb3BhY2l0eT" \
                "0iLjkiLz48cGF0aCBkPSJNMTIgNjRjMi0xMyAxMC0xOSAyMC0xOXMxOCA2IDIwIDE5eiIgZmlsbD0iI2ZmZiIgb3BhY2l0eT0iLj" \
                "kiLz48L3N2Zz4="

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
