# frozen_string_literal: true

module Poetry
  module Ui
    # The Icon family - inline SVG icons from the configured icon set.
    module Icon
      # The Icon component: template-less, rendering an icon's vendored,
      # pre-sanitized inner markup from the configured icon set
      # (`config.icon_library`, Lucide by default via poetry-lucide;
      # override per render with `library:`).
      #
      # The ARIA contract:
      # - `label:` given  -> standalone/informative: role="img" + aria-label
      # - no `label:`     -> decorative: aria-hidden="true" + focusable="false"
      #
      # @example A decorative icon inside a labeled control
      #   render Poetry::Ui::Icon::Component.new(name: :plus)
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Icons are decorative by default (aria-hidden); pass label: when the icon stands alone.",
          "Never inline raw <svg> markup where an icon exists - use poetry_icon."
        ].freeze

        option :name, :symbol, required: true, format: :"icon-name",
                               doc: "The icon's name in the active set. format: :\"icon-name\" is the " \
                                    "machine-readable value contract: the registry carries it, and literal names are " \
                                    "validated against the icon set statically - a misspelled name is caught before " \
                                    "it can crash a render."
        option :label, :string,
               doc: "The accessible name - given, the icon is standalone (role=img); absent, it is decorative " \
                    "(aria-hidden)."
        option :library, :symbol, doc: "Per-render icon set override (defaults to config.icon_library)."

        validate :icon_must_exist

        part "icon", "The <svg> root itself - the vendored icon markup renders inside; " \
                     "ARIA (label: vs decorative) rides here"

        # Renders the <svg> with the icon's inner markup.
        # @api private
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
        rescue Poetry::Core::IconNotFound => e
          raise if raise_on_missing_icon?

          config = self.class.config
          config.on_missing_icon&.call(name: name, library: library || config.icon_library, error: e)
          fallback = config.icon_fallback
          raise if fallback.nil?

          begin
            icon_set.fetch(fallback)
          rescue Poetry::Core::IconNotFound
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
            # container (a standalone icon once rendered 352px wide);
            # inside components the [&_svg]:size-4 rules still win
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
