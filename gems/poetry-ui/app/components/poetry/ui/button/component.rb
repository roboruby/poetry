# frozen_string_literal: true

module Poetry
  module Ui
    # Action buttons and button-styled links.
    module Button
      # A button. Variants carry semantic intent (one default-variant
      # action per view); size covers text and icon-only forms. Renders a
      # real <a> when href: is given, and a no-JS loading state
      # (aria-busy + spinner) via loading:.
      #
      # Icon-only sizes require label: - an icon button without an
      # accessible name raises.
      #
      # @example
      #   render Poetry::Ui::Button::Component.new(variant: :default) { "Save" }
      class Component < Poetry::Core::Component
        # The closed vocabulary for the variant axis.
        VARIANTS = %i[default destructive outline secondary ghost link].freeze
        # The closed vocabulary for the size axis; icon* are the square icon-only forms.
        SIZES = %i[default xs sm lg icon icon-xs icon-sm icon-lg].freeze
        # The closed vocabulary for the native type: attribute.
        TYPES = %i[button submit reset].freeze

        # The contract's agent-rules section (projected into the registry,
        # llms.txt, and the generated agent-rules.md).
        AGENT_RULES = [
          "Use poetry_button - never a raw <button> with hand-written Tailwind.",
          "The visible text is the content block: poetry_button { \"Save\" }. label: is ONLY the accessible name.",
          "Icon-only buttons (size: :icon*) MUST pass label: (the accessible name).",
          "Link-styled actions use variant: :link - not <a> with button classes.",
          "Navigation wearing button styling: pass href: (renders a real <a>; tag: :a is implied) - " \
          "never onclick navigation.",
          "Loading via loading: - never a manual disabled + spinner.",
          "Never nest an interactive element inside a Button.",
          "Pick the variant by intent; one primary (default) action per view."
        ].freeze

        # At least one of these must be present or nothing visible renders;
        # static checks read this without rendering.
        REQUIRES_ANY = [
          { hint: "nothing visible renders without one - label: is only the accessible name",
            content: true, slots: %w[leading trailing], options: %w[loading] }
        ].freeze

        # Optional leading visual, rendered inside the icon span.
        renders_one :leading
        # Optional trailing visual, rendered inside the icon span.
        renders_one :trailing

        # The visual intent axis; :destructive marks irreversible actions.
        style :variant, default: :default, required: true, variants: VARIANTS
        # The size axis; the icon* sizes are square icon-only forms (label: required).
        style :size, default: :default, required: true, variants: SIZES

        # The native button type; ignored when the button renders as an anchor.
        option :type, :symbol, default: :button
        # Renders the same styling on an <a> when :a - navigation wearing button clothes.
        option :tag, :symbol, default: :button
        # Disables the control (native disabled; aria-disabled on the anchor form).
        option :disabled, :boolean, default: false
        # The no-JS loading state: aria-busy, a spinner, and the control disabled.
        option :loading, :boolean, default: false
        # The accessible name for icon-only usage - not visible text.
        option :label, :string
        # The link target; implies the anchor form.
        option :href, :string

        validates :type, inclusion: { in: TYPES }
        validates :tag, inclusion: { in: %i[button a] }

        part "button", "The rendered control itself (<button>, or <a> when tag: :a) - " \
                       "every visual state rides here",
             states: {
               "data-variant" => { condition: "always - the resolved variant",
                                   values: VARIANTS.map(&:to_s) },
               "data-size" => { condition: "always - the resolved size", values: SIZES.map(&:to_s) },
               "data-loading" => "loading: is set (aria-busy rides along)"
             }
        part "icon", "Wrapper span around leading/trailing slot content - sizes and centers " \
                     "whatever it holds"
        part "label", "The content block's span (display: contents - children join the root's " \
                      "flex row directly)"
        part "spinner", "The loading indicator, swapped in for the leading icon while loading:"

        # Raises when an icon-only size lacks label:.
        # @api private
        def initialize(...)
          super
          return unless icon_only? && label.blank?

          # The accessible-icon rule: an icon-only control without an
          # accessible name never ships.
          raise ArgumentError, "icon-only Button requires label: (the accessible name)"
        end

        # Enforces that something visible renders.
        # @api private
        def before_render
          return if content? || leading? || trailing? || loading

          raise ArgumentError,
                "Button renders nothing visible: pass a content block (the visible text), " \
                "an icon slot (with_leading/with_trailing), or loading: - label: is only the accessible name"
        end

        # Whether size: is one of the square icon-only forms.
        # @api private
        def icon_only?
          size.to_s.start_with?("icon")
        end

        # href: implies the anchor: an href on a native <button> would be
        # silently dropped, leaving a dead control.
        # @api private
        def link_tag?
          tag == :a || href.present?
        end

        # @api private
        def root_tag
          link_tag? ? :a : :button
        end

        # @api private
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
