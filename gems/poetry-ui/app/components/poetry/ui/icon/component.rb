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

        part "icon", "The <svg> root itself - the vendored icon markup renders inside; " \
                     "ARIA (label: vs decorative) rides here"

        def call
          # Vendored + sanitized at vendor time (the fetch pipeline) - the
          # inner markup is trusted by construction; render never parses.
          content_tag(:svg, resolved_markup.html_safe, **svg_attributes.to_attributes)
        end

        private

        def icon_set
          Poetry::Core::Icons.set(library)
        end

        # The missing-icon policy. poetry check catches literal
        # names statically; a DYNAMIC name (a DB value, a user setting) only
        # surfaces here - and a bad one should not 500 production. Dev/test
        # keep the raise (config.raise_on_missing_icon nil = auto via
        # Rails.env.local?); elsewhere the configured fallback renders and
        # config.on_missing_icon fires (per render - dedup is the app's
        # concern). A nil or itself-missing fallback re-raises the original.
        def resolved_markup
          icon_set.fetch(name)
        rescue ArgumentError => e
          raise if raise_on_missing_icon?

          config = self.class.config
          config.on_missing_icon&.call(name: name, library: library || config.icon_library, error: e)
          fallback = config.icon_fallback
          raise if fallback.nil?

          begin
            icon_set.fetch(fallback)
          rescue ArgumentError
            raise e
          end
        end

        def raise_on_missing_icon?
          configured = self.class.config.raise_on_missing_icon
          return configured unless configured.nil?

          !defined?(Rails.env) || Rails.env.local?
        end

        def icon_must_exist
          return if name.blank? || icon_set.include?(name)

          suggestion = Poetry::Core::Icons.suggest(name, icon_set.names)
          hint = suggestion ? " - did you mean #{suggestion.to_sym.inspect}?" : ""
          errors.add(:name, "unknown icon #{name.inspect} in the " \
                            "#{library || self.class.config.icon_library} set#{hint}")
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
