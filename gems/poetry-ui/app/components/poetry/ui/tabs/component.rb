# frozen_string_literal: true

module Poetry
  module Ui
    # Tabbed views switched by a tablist.
    module Tabs
      # A tablist of triggers that switches between panels. Declare each
      # tab with with_tab (title plus a panel block) and the component
      # wires the tab/tablist/tabpanel roles, their ids, and the keyboard:
      # arrow keys move focus along the tablist and activate the focused
      # tab. The active panel is server-rendered visible, so the initial
      # view needs no JS.
      #
      # default: picks the active tab by value (otherwise the first
      # enabled tab wins); label: names the tablist for assistive tech -
      # recommended when a page has several tab sets.
      #
      # @example
      #   <%= poetry_tabs(default: "account", label: "Account settings") do |tabs| %>
      #     <% tabs.with_tab("Account", value: "account") do %>...panel...<% end %>
      #     <% tabs.with_tab("Password", value: "password") do %>...panel...<% end %>
      #   <% end %>
      class Component < Poetry::Core::Component
        # The closed vocabulary for the orientation axis.
        ORIENTATIONS = %i[horizontal vertical].freeze
        # The closed vocabulary for the list-variant axis.
        VARIANTS = %i[default line].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Declare tabs with with_tab(title, value:) + the panel block (or defer: for a " \
          "lazy turbo-frame panel) - never hand-wire role=tab/tabpanel ids.",
          "panel: false declares a list-only tab (no tabpanel renders, the trigger drops " \
          "aria-controls) - for demos/pattern shells; real tab sets carry panels.",
          "default: picks the server-rendered active tab (the first enabled tab otherwise) - the " \
          "panel is visible without JS.",
          "label: names the tablist (aria-label) - recommended whenever the page has several tab sets.",
          "Tabs switch VIEWS of one context; use navigation (links) when the URL should change."
        ].freeze

        # The same facts the before_render raise enforces, stated
        # statically: poetry check flags the omission without rendering.
        REQUIRED_SLOTS = { tab: "at least one tab" }.freeze

        renders_many :tabs,
                     doc: "Declares one tab: the title, its value:, and the panel as the block (defer: swaps in a " \
                          "lazy turbo-frame panel; panel: false declares a list-only tab). Omitting all three " \
                          "raises.",
                     renders: lambda { |title, value:, disabled: false, defer: nil, panel: true, &block|
                       unless block || defer || panel == false
                         raise ArgumentError,
                               "Tabs tab #{title.inspect} requires a panel block, defer:, or panel: false"
                       end

                       tab_defs << Tab.new(title: title, value: value.to_s, disabled: disabled, panel: block,
                                           defer: defer, panel_less: panel == false)
                       nil
                     }

        use_stimulus do
          on :root do
            controller(:tabs) { register }
          end
          # Both controllers declare on one element: roving-focus registers
          # and owns the keyboard; the tabs controller is NOT registered on
          # the list - its focus_activate action routes up to the root
          # instance.
          on :list do
            controller :roving_focus do
              register
              value :orientation
              value :loop, true
              action :keydown, on: :keydown
            end
            controller :tabs do
              action :focus_activate, on: event(:roving_focus, :entry)
            end
          end
          on :trigger do
            controller(:tabs) { action :activate, on: :click }
          end
        end

        # The operate surface: activate a tab by its value (registered per
        # instance, opt-in - see poetry-agent).
        tool :set_value,
             description: "Activate the tab whose value matches and show its panel.",
             params: { value: { type: "string", required: true, description: "The tab's value." } },
             executes: %i[tabs set_value],
             mutating: true

        # The rendered instance knows its tab values: the payload's schema
        # carries them as the enum, so an agent can only ask for a tab that
        # exists (the class-level projection stays a plain string).
        def webmcp_tool_definition(definition)
          return definition unless definition["name"] == "set_value"

          values = tab_defs.map(&:value)
          return definition if values.empty?

          schema = definition.fetch("inputSchema")
          value = schema.fetch("properties").fetch("value").merge("enum" => values)
          definition.merge("inputSchema" => schema.merge("properties" => schema["properties"].merge("value" => value)))
        end

        option :default, :string,
               doc: "The value of the server-rendered active tab; defaults to the first enabled tab. Raises when it " \
                    "matches no tab."
        option :label, :string, doc: "The tablist's accessible name - recommended when a page has several tab sets."
        option :orientation, :symbol, default: :horizontal,
                                      doc: "The tab axis; :vertical stacks the triggers and flips the arrow keys."
        option :variant, :symbol, default: :default,
                                  doc: "The list's visual treatment: :default a filled capsule, :line an underline " \
                                       "indicator."

        validates :orientation, inclusion: { in: ORIENTATIONS }
        validates :variant, inclusion: { in: VARIANTS }

        part "tabs", "Root wrapper - the orientation rides here and flips the flex direction",
             states: {
               "data-orientation" => { condition: "the tab axis (matches aria-orientation on the list)",
                                       values: %w[horizontal vertical] }
             }
        part "tabs-list", "The role=tablist row of triggers - the roving-focus keyboard group and " \
                          "the visual variant ride here",
             states: {
               "data-variant" => "the list treatment - default (filled capsule) or line (underline indicator)"
             }
        part "tabs-trigger", "One role=tab button per tab",
             states: {
               "data-active" => "the selected tab (the controller moves it with aria-selected on activation)",
               "data-disabled" => "tab is disabled - also filters it from the roving-focus collection",
               "data-value" => "the tab's value - the key the controller matches panels against"
             }
        part "tabs-content", "One role=tabpanel per tab - only the active panel is visible",
             states: {
               "data-hidden" => "panel is inactive (paired with the hidden property - the controller " \
                                "flips both)",
               "data-value" => "the owning tab's value"
             }

        # @api private
        def before_render
          raise ArgumentError, "Tabs requires at least one with_tab" unless tabs?

          return unless default.present? && tab_defs.none? { |tab| tab.value == default }

          raise ArgumentError, "Tabs default: #{default.inspect} matches no tab value " \
                               "(#{tab_defs.map(&:value).inspect})"
        end

        # @api private
        def tab_defs
          @tab_defs ||= []
        end

        # The server-rendered active tab: default: when given, else the
        # first enabled tab.
        # @api private
        def active_value
          @active_value ||= default.presence || tab_defs.reject(&:disabled).first&.value || tab_defs.first.value
        end

        # @api private
        def active?(tab)
          tab.value == active_value
        end

        # @api private
        def trigger_id(tab) = "#{instance_id}-trigger-#{tab.value}"
        # @api private
        def panel_id(tab) = "#{instance_id}-panel-#{tab.value}"

        # defer: swaps the panel body for a lazy turbo-frame - a
        # hidden panel is not visible, so Turbo fetches on first
        # activation with zero tabs-controller involvement. The panel
        # block (if given) becomes the frame's placeholder.
        # @api private
        def panel_body(tab)
          return capture(&tab.panel) unless tab.defer

          helpers.poetry_deferred(src: tab.defer) { tab.panel ? capture(&tab.panel) : nil }
        end

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "tabs", "data-orientation" => orientation
            }.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end

        # @api private
        def list_attributes
          attrs = {
            "role" => "tablist", "data-slot" => "tabs-list", "data-variant" => variant,
            "aria-orientation" => orientation,
            "class" => "#{css(:list)} #{css(:"list_#{variant}")}".strip
          }
          attrs["aria-label"] = label if label.present?
          attrs.merge(stimulus_attributes_for(:list))
        end

        # @api private
        def trigger_attributes(tab)
          attrs = {
            "type" => "button", "role" => "tab", "id" => trigger_id(tab),
            "data-slot" => "tabs-trigger", "data-value" => tab.value,
            "data-poetry-collection-item" => "",
            "aria-selected" => active?(tab).to_s,
            "tabindex" => active?(tab) ? "0" : "-1",
            "class" => css(:trigger)
          }.merge(stimulus_attributes_for(:trigger))
          attrs["aria-controls"] = panel_id(tab) unless tab.panel_less
          attrs["data-active"] = "" if active?(tab)
          if tab.disabled
            attrs["disabled"] = true
            attrs["data-disabled"] = "" # the roving-focus collection filter
          end
          attrs
        end

        # @api private
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

        # One declared tab (built by with_tab).
        # @api private
        Tab = Data.define(:title, :value, :disabled, :panel, :defer, :panel_less)

        private

        def instance_id
          @instance_id ||= poetry_instance_id("poetry-tabs")
        end

        private :tab_defs, :active_value, :active?, :trigger_id, :panel_id, :panel_body, :root_attributes
        private :list_attributes, :trigger_attributes, :panel_attributes
      end
    end
  end
end
