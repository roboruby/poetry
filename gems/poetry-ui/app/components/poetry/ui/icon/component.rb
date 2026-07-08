# frozen_string_literal: true

module Poetry
  module Ui
    module Icon
      # The Icon component: template-less, rendering an icon's vendored,
      # pre-sanitized inner markup from the configured icon set ( -
      # `config.icon_library`, Lucide by default via poetry-lucide;
      # override per render with `library:`).
      #
      # The ARIA contract (locked at M5 spec time):
      # - `label:` given  -> standalone/informative: role="img" + aria-label
      # - no `label:`     -> decorative: aria-hidden="true" + focusable="false"
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Icons are decorative by default (aria-hidden); pass label: when the icon stands alone.",
          "Never inline raw <svg> markup where an icon exists - use poetry_icon."
        ].freeze

        # format: :"icon-name" is the machine-readable value contract:
        # the registry carries it, poetry check validates literals against the
        # icon set statically - the W2 :folder_plus render crash, moved left.
        option :name, :symbol, required: true, format: :"icon-name"
        option :label, :string
        option :library, :symbol

        validate :icon_must_exist

        def call
          # Vendored + sanitized at vendor time (the fetch pipeline) - the
          # inner markup is trusted by construction; render never parses.
          content_tag(:svg, icon_set.fetch(name).html_safe, **svg_attributes.to_attributes)
        end

        private

        def icon_set
          Poetry::Core::Icons.set(library)
        end

        def icon_must_exist
          return if name.blank? || icon_set.include?(name)

          errors.add(:name, "unknown icon #{name.inspect} in the #{library || self.class.config.icon_library} set")
        end

        def svg_attributes
          html_attributes.merge_if_not_set(default_svg_attributes.merge(aria_attributes))
        end

        def default_svg_attributes
          {
            "xmlns" => "http://www.w3.org/2000/svg",
            # Lucide's intrinsic box. Without it a standalone icon fills its
            # container (the 2026-07-01 browser pass rendered a 352px
            # rocket); inside components the [&_svg]:size-4 rules still win
            # (CSS beats presentation attributes).
            "width" => "24",
            "height" => "24",
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
