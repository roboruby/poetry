# frozen_string_literal: true

module Poetry
  module Ui
    module Tabs
      # The Tabs - a tablist of triggers switching panels, data-driven like
      # Accordion: declare each tab (title + panel block) and the component
      # owns the ARIA wiring (role=tab/tablist/tabpanel, aria-selected /
      # -controls / -labelledby ids), the server-rendered active tab, and
      # the two-controller split: poetry--core--tabs (activation) on the
      # root + poetry--core--roving-focus (keyboard) on the tablist.
      #
      #   <%= poetry_tabs(default: "account", label: "Account settings") do |tabs| %>
      #     <% tabs.with_tab("Account", value: "account") do %>...panel...<% end %>
      #     <% tabs.with_tab("Password", value: "password") do %>...panel...<% end %>
      #   <% end %>
      class Component < Poetry::Core::Component
        ORIENTATIONS = %i[horizontal vertical].freeze
        VARIANTS = %i[default line].freeze

        AGENT_RULES = [
          "Declare tabs with with_tab(title, value:) + the panel block (or defer: for a " \
          "lazy turbo-frame panel) - never hand-wire role=tab/tabpanel ids.",
          "default: picks the server-rendered active tab (the first enabled tab otherwise) - the " \
          "panel is visible without JS.",
          "label: names the tablist (aria-label) - recommended whenever the page has several tab sets.",
          "Tabs switch VIEWS of one context; use navigation (links) when the URL should change."
        ].freeze

        TABS_CONTROLLER = %i[poetry core tabs].freeze
        ROVING = %i[poetry core roving_focus].freeze

        Tab = Data.define(:title, :value, :disabled, :panel, :defer)

        option :default, :string
        option :label, :string
        option :orientation, :symbol, default: :horizontal
        # The variant styles the LIST element (an element-variant, the Empty
        # media pattern) - the root carries no variant classes.
        option :variant, :symbol, default: :default

        validates :orientation, inclusion: { in: ORIENTATIONS }
        validates :variant, inclusion: { in: VARIANTS }

        renders_many :tabs, lambda { |title, value:, disabled: false, defer: nil, &panel|
          raise ArgumentError, "Tabs tab #{title.inspect} requires a panel block or defer:" unless panel || defer

          tab_defs << Tab.new(title: title, value: value.to_s, disabled: disabled, panel: panel, defer: defer)
          nil
        }

        def tab_defs
          @tab_defs ||= []
        end

        def before_render
          raise ArgumentError, "Tabs requires at least one with_tab" unless tabs?

          return unless default.present? && tab_defs.none? { |tab| tab.value == default }

          raise ArgumentError, "Tabs default: #{default.inspect} matches no tab value " \
                               "(#{tab_defs.map(&:value).inspect})"
        end

        # The server-rendered active tab: default: when given, else the
        # first enabled tab.
        def active_value
          @active_value ||= default.presence || tab_defs.reject(&:disabled).first&.value || tab_defs.first.value
        end

        def active?(tab)
          tab.value == active_value
        end

        def trigger_id(tab) = "#{instance_id}-trigger-#{tab.value}"
        def panel_id(tab) = "#{instance_id}-panel-#{tab.value}"

        # N13 W5: defer: swaps the panel body for a lazy turbo-frame - a
        # hidden panel is not visible, so Turbo fetches on first
        # activation with zero tabs-controller involvement. The panel
        # block (if given) becomes the frame's placeholder.
        def panel_body(tab)
          return capture(&tab.panel) unless tab.defer

          helpers.poetry_deferred(src: tab.defer) { tab.panel ? capture(&tab.panel) : nil }
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "tabs", "data-orientation" => orientation
            }.merge(root_stimulus_attributes).merge(component_data_attributes)
          )
        end

        def list_attributes
          attrs = {
            "role" => "tablist", "data-slot" => "tabs-list", "data-variant" => variant,
            "aria-orientation" => orientation,
            "class" => "#{css(:list)} #{css(:"list_#{variant}")}".strip
          }
          attrs["aria-label"] = label if label.present?
          attrs.merge(list_stimulus_attributes)
        end

        def trigger_attributes(tab)
          attrs = {
            "type" => "button", "role" => "tab", "id" => trigger_id(tab),
            "data-slot" => "tabs-trigger", "data-value" => tab.value,
            "data-poetry-collection-item" => "",
            "aria-selected" => active?(tab).to_s, "aria-controls" => panel_id(tab),
            "tabindex" => active?(tab) ? "0" : "-1",
            "class" => css(:trigger),
            "data-action" => "click->poetry--core--tabs#activate"
          }
          attrs["data-active"] = "" if active?(tab)
          if tab.disabled
            attrs["disabled"] = true
            attrs["data-disabled"] = "" # the roving-focus collection filter
          end
          attrs
        end

        def panel_attributes(tab)
          attrs = {
            "role" => "tabpanel", "id" => panel_id(tab), "data-slot" => "tabs-content",
            "data-value" => tab.value, "aria-labelledby" => trigger_id(tab),
            "tabindex" => "0", "class" => css(:content)
          }
          unless active?(tab)
            attrs["hidden"] = true
            attrs["data-hidden"] = ""
          end
          attrs
        end

        private

        def instance_id
          @instance_id ||= "poetry-tabs-#{SecureRandom.hex(4)}"
        end

        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          tabs = Poetry::Core::Stimulus::Builder.new(TABS_CONTROLLER, attrs)
          tabs.register_controller
          attrs.to_attributes
        end

        # BOTH builders into ONE Attributes instance (the ToggleGroup
        # lesson): roving-focus registers here and owns the keyboard; the
        # tabs controller is NOT registered on the list - its focusin action
        # routes up to the root instance.
        def list_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          roving = Poetry::Core::Stimulus::Builder.new(ROVING, attrs)
          roving.register_controller
          roving.with_value(:orientation, orientation)
          roving.with_value(:loop, true)
          roving.with_action(:keydown, on: :keydown)
          tabs = Poetry::Core::Stimulus::Builder.new(TABS_CONTROLLER, attrs)
          tabs.with_action(:focus_activate, on: "poetry--core--roving-focus:entry")
          attrs.to_attributes
        end
      end
    end
  end
end
