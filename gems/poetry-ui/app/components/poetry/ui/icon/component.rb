# frozen_string_literal: true

module Poetry
  module Ui
    module Icon
      # The minimal Icon (M3.5 - pulled forward from M5 because Button's
      # anatomy composes it). Template-less; renders an inline SVG from a
      # tiny vendored Lucide subset. The full icon pipeline (pinned-SHA
      # vendoring + sanitization + per-set adapters + poetry-lucide) lands
      # at M5 - this component keeps the same public surface.
      #
      # The ARIA contract (locked at M5 spec time):
      # - `label:` given  -> standalone/informative: role="img" + aria-label
      # - no `label:`     -> decorative: aria-hidden="true" + focusable="false"
      class Component < Poetry::Core::Component
        # Vendored, hand-audited Lucide path data (24x24, stroke-based).
        # Trusted content by construction; the M5 pipeline sanitizes at
        # vendor time, never at render time.
        ICONS = {
          plus: '<path d="M5 12h14"/><path d="M12 5v14"/>',
          trash: '<path d="M3 6h18"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/>' \
                 '<path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>',
          "chevron-right": '<path d="m9 18 6-6-6-6"/>'
        }.freeze

        AGENT_RULES = [
          "Icons are decorative by default (aria-hidden); pass label: when the icon stands alone.",
          "Never inline raw <svg> markup where an icon exists - use poetry_icon."
        ].freeze

        option :name, :symbol, required: true
        option :label, :string

        validates :name, inclusion: { in: ICONS.keys }

        def call
          content_tag(:svg, ICONS.fetch(name).html_safe, **svg_attributes.to_attributes)
        end

        private

        def svg_attributes
          html_attributes.merge_if_not_set(default_svg_attributes.merge(aria_attributes))
        end

        def default_svg_attributes
          {
            "xmlns" => "http://www.w3.org/2000/svg",
            "viewBox" => "0 0 24 24",
            "fill" => "none",
            "stroke" => "currentColor",
            "stroke-width" => "2",
            "stroke-linecap" => "round",
            "stroke-linejoin" => "round",
            "data-slot" => "icon"
          }.merge(component_data_attributes)
        end

        def aria_attributes
          if label.present?
            { "role" => "img", "aria-label" => label }
          else
            { "aria-hidden" => "true", "focusable" => "false" }
          end
        end
      end
    end
  end
end
