# frozen_string_literal: true

module Poetry
  module Ui
    module Button
      # The golden Button (Button, the v2-contract
      # reference every other component plan diffs against). What it
      # establishes suite-wide: data-slot = role / data-component +
      # data-variant + data-size self-identification; semantic-role tokens
      # only; the 3px no-offset focus ring; `tag: :a` polymorphic root;
      # icon-only REQUIRES label: (ArgumentError); loading = aria-busy +
      # sr-only text + a static spinner, fully working with zero JS.
      class Component < Poetry::Core::Component
        VARIANTS = %i[default destructive outline secondary ghost link].freeze
        SIZES = %i[default xs sm lg icon icon-xs icon-sm icon-lg].freeze
        TYPES = %i[button submit reset].freeze

        # The contract's agent-rules section (projected into the registry,
        # llms.txt, and the generated agent-rules.md).
        AGENT_RULES = [
          "Use poetry_button - never a raw <button> with hand-written Tailwind.",
          "Icon-only buttons (size: :icon*) MUST pass label: (the accessible name).",
          "Link-styled actions use variant: :link - not <a> with button classes.",
          "Loading via loading: - never a manual disabled + spinner.",
          "Never nest an interactive element inside a Button.",
          "Pick the variant by intent; one primary (default) action per view."
        ].freeze

        style :variant, default: :default, required: true, variants: VARIANTS
        style :size, default: :default, required: true, variants: SIZES

        option :type, :symbol, default: :button
        option :tag, :symbol, default: :button
        option :disabled, :boolean, default: false
        option :loading, :boolean, default: false
        option :label, :string
        option :href, :string

        validates :type, inclusion: { in: TYPES }
        validates :tag, inclusion: { in: %i[button a] }

        renders_one :leading
        renders_one :trailing

        def initialize(...)
          super
          return unless icon_only? && label.blank?

          # The accessible-icon rule (the base contract base-contract borrow): an
          # icon-only control without an accessible name never ships.
          raise ArgumentError, "icon-only Button requires label: (the accessible name)"
        end

        def icon_only?
          size.to_s.start_with?("icon")
        end

        def link_tag?
          tag == :a
        end

        def root_tag
          link_tag? ? :a : :button
        end

        def root_attributes
          html_attributes.merge_if_not_set(base_attributes.merge(tag_attributes))
        end

        private

        def base_attributes
          attrs = { "data-slot" => "button", "data-variant" => variant, "data-size" => size }
                  .merge(component_data_attributes)
          attrs["aria-label"] = label if label.present?
          if loading
            attrs["data-loading"] = true
            attrs["aria-busy"] = true
          end
          attrs
        end

        # Native <button> gets native semantics (type, real disabled);
        # `tag: :a` is navigation-styled-as-button: role="button" + the
        # faux-disabled convention (aria-disabled, href withheld).
        def tag_attributes
          link_tag? ? link_attributes : button_attributes
        end

        def link_attributes
          attrs = { "role" => "button" }
          if disabled || loading
            attrs["aria-disabled"] = true
          elsif href.present?
            attrs["href"] = href
          end
          attrs
        end

        def button_attributes
          attrs = { "type" => type }
          attrs["disabled"] = true if disabled || loading
          attrs
        end
      end
    end
  end
end
