# frozen_string_literal: true

require_relative "../pointer"
require_relative "../markdown"

module Poetry
  module Agent
    module A2UI
      # The catalog bindings a {Surface} renders through: how a catalog's
      # components reference their children, which of them are bound
      # inputs, and how each one renders with Poetry.
      module Catalogs
        # The A2UI basic catalog (v1.0) rendered with Poetry: every one of
        # its components maps onto a library component or a plain element,
        # its enums onto the library's axes, its bound inputs onto named
        # form controls, and its `checks` onto native constraint
        # attributes where the browser can enforce them.
        class Basic
          # The catalog id agents name in `createSurface`.
          ID = "https://a2ui.org/specification/v1_0/catalogs/basic/catalog.json"

          # Main-axis alignment classes by the catalog's `justify` values.
          JUSTIFY = { "start" => "justify-start", "center" => "justify-center", "end" => "justify-end",
                      "spaceBetween" => "justify-between", "spaceAround" => "justify-around",
                      "spaceEvenly" => "justify-evenly", "stretch" => "justify-stretch" }.freeze
          # Cross-axis alignment classes by the catalog's `align` values.
          ALIGN = { "start" => "items-start", "center" => "items-center", "end" => "items-end",
                    "stretch" => "items-stretch" }.freeze
          # Object-fit classes by the Image `fit` values.
          FIT = { "contain" => "object-contain", "cover" => "object-cover", "fill" => "object-fill",
                  "none" => "object-none", "scaleDown" => "object-scale-down" }.freeze
          # Sizing classes by the Image `variant` values.
          IMAGE_VARIANTS = { "icon" => "size-6", "avatar" => "size-10 rounded-full",
                             "smallFeature" => "w-full max-w-32", "mediumFeature" => "w-full max-w-sm",
                             "largeFeature" => "w-full max-w-2xl", "header" => "w-full" }.freeze
          # Poetry's Button variant by the catalog's Button `variant` values.
          BUTTON_VARIANTS = { "primary" => :default, "default" => :outline, "borderless" => :ghost }.freeze
          # Lucide names for the Material-style icon names agents tend to
          # emit; anything else converts camelCase to kebab-case as is.
          ICON_ALIASES = { "skip-previous" => "skip-back", "skip-next" => "skip-forward", "play-arrow" => "play",
                           "favorite" => "heart", "favorite-border" => "heart", "close" => "x",
                           "arrow-back" => "arrow-left", "arrow-forward" => "arrow-right",
                           "more-vert" => "ellipsis-vertical", "more-horiz" => "ellipsis", "delete" => "trash-2",
                           "edit" => "pencil", "add" => "plus", "remove" => "minus", "notifications" => "bell",
                           "person" => "user", "email" => "mail", "schedule" => "clock", "event" => "calendar",
                           "location-on" => "map-pin", "visibility" => "eye", "visibility-off" => "eye-off",
                           "home" => "house", "shopping-cart" => "shopping-cart" }.freeze
          # A ChoicePicker's resolved options, binding, selection, and label.
          Choice = Struct.new(:options, :path, :selected, :label, keyword_init: true)
          # The bound kinds of the input components.
          INPUT_KINDS = { "TextField" => :string, "CheckBox" => :boolean, "Slider" => :number,
                          "ChoicePicker" => :string_list, "DateTimeInput" => :string }.freeze

          # @return [String]
          def id
            ID
          end

          # @return [Functions] the basic catalog's function set
          def functions
            Functions.basic
          end

          # The child references of a component (ids, id lists, templates).
          #
          # @param component [Hash]
          # @return [Array<Object>]
          def references(component)
            case component["component"]
            when "Row", "Column", "List" then [component["children"]]
            when "Card", "Button" then [component["child"]]
            when "Modal" then [component["trigger"], component["content"]]
            when "Tabs" then Array(component["tabs"]).map { |tab| tab.is_a?(Hash) ? tab["child"] : nil }
            else []
            end.compact
          end

          # The bound input of a component, if it is one.
          #
          # @param component [Hash]
          # @param scope [String, nil]
          # @return [Array<Hash>] `{ path:, kind: }`
          def inputs(component, scope)
            kind = INPUT_KINDS[component["component"]]
            path = binding_path(component["value"])
            return [] unless kind && path

            kind = :number if component["component"] == "TextField" && component["variant"] == "number"
            [{ path: Pointer.absolute(path, scope), kind: kind }]
          end

          # @param component [Hash]
          # @param scope [String, nil]
          # @param renderer [Renderer]
          # @return [String] HTML
          def render(component, scope, renderer)
            name = component["component"]
            method = :"render_#{name.gsub(/([a-z])([A-Z])/, '\1_\2').downcase}"
            return renderer.warn("unknown basic catalog component #{name.inspect}") unless respond_to?(method, true)

            send(method, component, scope, renderer)
          end

          private

          def render_text(component, scope, renderer)
            text = renderer.text(component["text"], scope)
            if component["variant"] == "caption"
              renderer.view.tag.div(renderer.markdown(text), class: "text-sm text-muted-foreground")
            else
              renderer.component(Poetry::Ui::Typeset::Component) { renderer.markdown(text) }
            end
          end

          def render_image(component, scope, renderer)
            url = renderer.text(component["url"], scope)
            return renderer.blank if url.empty?

            classes = ["rounded-md", FIT.fetch(component["fit"], "object-fill"),
                       IMAGE_VARIANTS.fetch(component["variant"], IMAGE_VARIANTS["mediumFeature"])]
            renderer.view.tag.img(src: url, alt: renderer.text(component["description"], scope),
                                  class: classes.join(" "), loading: "lazy")
          end

          def render_icon(component, scope, renderer)
            name = icon_name(renderer.text(component["name"], scope))
            return renderer.blank if name.empty?

            renderer.component(Poetry::Ui::Icon::Component, name: name, class: "size-5")
          end

          def icon_name(raw)
            kebab = raw.strip.gsub(/([a-z0-9])([A-Z])/, '\1-\2').tr("_ ", "--").downcase
            ICON_ALIASES.fetch(kebab, kebab)
          end

          def render_video(component, scope, renderer)
            url = renderer.text(component["url"], scope)
            return renderer.blank if url.empty?

            poster = renderer.text(component["posterUrl"], scope)
            renderer.view.tag.video(controls: true, src: url, poster: poster.empty? ? nil : poster,
                                    class: "w-full rounded-md")
          end

          def render_audio_player(component, scope, renderer)
            url = renderer.text(component["url"], scope)
            return renderer.blank if url.empty?

            description = renderer.text(component["description"], scope)
            renderer.view.tag.audio(controls: true, src: url, "aria-label": description.empty? ? nil : description,
                                    class: "w-full")
          end

          def render_row(component, scope, renderer)
            flex(component, scope, renderer, "flex-row")
          end

          def render_column(component, scope, renderer)
            flex(component, scope, renderer, "flex-col")
          end

          def flex(component, scope, renderer, direction)
            classes = ["flex", direction, "gap-4", JUSTIFY.fetch(component["justify"], "justify-start"),
                       ALIGN.fetch(component["align"], "items-stretch")]
            renderer.view.tag.div(weighted_children(component["children"], scope, renderer),
                                  class: classes.join(" "), "aria-label": renderer.aria_label(component, scope))
          end

          # A child's `weight` is its flex-grow share of the container.
          def weighted_children(reference, scope, renderer)
            items = renderer.surface.expand(reference, scope).map do |child_id, child_scope|
              html = renderer.render_component(child_id, child_scope)
              weight = renderer.surface.component(child_id)&.fetch("weight", nil)
              weight.is_a?(Numeric) ? renderer.view.tag.div(html, style: "flex: #{weight} 1 0%") : html
            end
            renderer.view.safe_join(items)
          end

          def render_list(component, scope, renderer)
            horizontal = component["direction"] == "horizontal"
            classes = ["flex gap-2", horizontal ? "flex-row overflow-x-auto" : "flex-col overflow-y-auto",
                       ALIGN.fetch(component["align"], "items-stretch")]
            renderer.view.tag.div(renderer.render_children(component["children"], scope), class: classes.join(" "))
          end

          def render_card(component, scope, renderer)
            renderer.component(Poetry::Ui::Card::Component) { renderer.render_children(component["child"], scope) }
          end

          def render_tabs(component, scope, renderer)
            tabs = Array(component["tabs"]).grep(Hash)
            return renderer.blank if tabs.empty?

            label = renderer.aria_label(component, scope) || "Tabs"
            renderer.component(Poetry::Ui::Tabs::Component, label: label) do |instance|
              tabs.each_with_index do |tab, index|
                instance.with_tab(renderer.text(tab["title"], scope), value: "tab-#{index}") do
                  renderer.render_children(tab["child"], scope)
                end
              end
              nil
            end
          end

          def render_divider(component, _scope, renderer)
            orientation = component["axis"] == "vertical" ? :vertical : :horizontal
            renderer.component(Poetry::Ui::Separator::Component, orientation: orientation)
          end

          # The trigger's Button collapses into the dialog's own trigger
          # button (no nested interactives); anything else renders inside it.
          def render_modal(component, scope, renderer)
            trigger = renderer.surface.component(component["trigger"])
            return renderer.warn("Modal #{component["id"].inspect}: unknown trigger") unless trigger

            title = renderer.aria_label(component, scope) || label_of(trigger, scope, renderer) || "Dialog"
            renderer.component(Poetry::Ui::Dialog::Component) do |dialog|
              dialog.with_trigger(variant: BUTTON_VARIANTS.fetch(trigger["variant"], :outline)) do
                if trigger["component"] == "Button"
                  button_content(trigger, scope, renderer)
                else
                  renderer.render_component(component["trigger"], scope)
                end
              end
              dialog.with_title { title }
              renderer.render_children(component["content"], scope)
            end
          end

          def render_button(component, scope, renderer)
            attributes = { variant: BUTTON_VARIANTS.fetch(component["variant"], :outline) }
            label = renderer.aria_label(component, scope)
            attributes[:aria] = { label: label } if label
            attributes.merge!(action_attributes(component, scope, renderer))
            keyed(component, scope, renderer, attributes)
            button = renderer.component(Poetry::Ui::Button::Component, attributes) do
              button_content(component, scope, renderer)
            end
            with_error(component, scope, renderer, button)
          end

          # An agent event submits; `openUrl` links (the function validates
          # the URL); any other local action has no renderer-side meaning.
          def action_attributes(component, scope, renderer)
            action = component["action"]
            return { type: :button } unless action.is_a?(Hash)
            return renderer.submit_attributes(component, scope) if action["event"].is_a?(Hash)

            call = action["functionCall"]
            return { type: :button } unless call.is_a?(Hash)

            if call["call"] == "openUrl"
              url = renderer.call_function("openUrl", call["args"], scope)
              return { href: url } if url
            else
              renderer.warn("Button #{component["id"].inspect}: local action #{call["call"].inspect} is not supported")
            end
            { type: :button, disabled: true }
          end

          # A checked control carries an error slot the server fills on a
          # rejected action and the client-side evaluator fills as the user
          # types; an unchecked control without a failure renders bare.
          def with_error(component, scope, renderer, control)
            error = renderer.error_for(component, scope)
            return control unless error || component["checks"].is_a?(Array)

            note = renderer.view.tag.p(error, id: "#{renderer.control_id(component, scope)}-error",
                                              class: "text-sm text-destructive", role: "alert",
                                              hidden: error.nil?, data: { a2ui_error_for: renderer.current_key })
            renderer.view.safe_join([control, note])
          end

          # The attributes that let the client-side evaluator find a control
          # and read its error slot.
          def keyed(component, scope, renderer, attributes)
            attributes[:data] = (attributes[:data] || {}).merge(a2ui_key: renderer.current_key)
            if component["checks"].is_a?(Array)
              described = "#{renderer.control_id(component, scope)}-error"
              attributes[:aria] = (attributes[:aria] || {}).merge(describedby: described)
            end
            attributes
          end

          # A Text child becomes the button's label (plain, no block markup).
          def button_content(component, scope, renderer)
            label = label_of(component, scope, renderer)
            label || renderer.render_children(component["child"], scope)
          end

          def label_of(component, scope, renderer)
            child = renderer.surface.component(component["child"])
            return unless child && child["component"] == "Text"

            Markdown.strip(renderer.text(child["text"], scope))
          end

          def render_text_field(component, scope, renderer)
            path = binding_path(component["value"])
            attributes = { id: renderer.control_id(component, scope), value: renderer.text(component["value"], scope) }
            attributes[:name] = renderer.input_name(path, scope) if path
            placeholder = renderer.text(component["placeholder"], scope)
            attributes[:placeholder] = placeholder unless placeholder.empty?
            attributes.merge!(check_attributes(component))
            error = renderer.error_for(component, scope)
            attributes[:invalid] = true if error
            keyed(component, scope, renderer, attributes)
            control = if component["variant"] == "longText"
                        renderer.component(Poetry::Ui::Textarea::Component, attributes.except(:type).merge(rows: 3))
                      else
                        attributes[:type] ||= { "number" => :number, "obscured" => :password }.fetch(
                          component["variant"], :text
                        )
                        renderer.component(Poetry::Ui::Input::Component, attributes)
                      end
            field = { id: attributes[:id], label_text: renderer.text(component["label"], scope) }
            field[:required] = true if attributes[:required]
            field[:invalid] = true if error
            with_error(component, scope, renderer, renderer.component(Poetry::Ui::Field::Component, field) { control })
          end

          def render_check_box(component, scope, renderer)
            path = binding_path(component["value"])
            attributes = { label: renderer.text(component["label"], scope), value: "true", unchecked_value: "false",
                           checked: renderer.resolve(component["value"], scope) == true }
            attributes[:name] = renderer.input_name(path, scope) if path
            attributes[:required] = true if check_attributes(component)[:required]
            keyed(component, scope, renderer, attributes)
            with_error(component, scope, renderer, renderer.component(Poetry::Ui::Checkbox::Component, attributes))
          end

          # `filterable` picks through a Combobox (single or multiple); chips
          # lay the choices out as a wrapping row; the default is a radio
          # group or a checkbox list.
          # `filterable` picks through a Combobox (single or multiple); chips
          # lay the choices out as a wrapping row; the default is a radio
          # group or a checkbox list.
          def render_choice_picker(component, scope, renderer)
            choice = Choice.new(options: Array(component["options"]).grep(Hash), path: binding_path(component["value"]),
                                selected: Array(renderer.resolve(component["value"], scope)).map(&:to_s),
                                label: renderer.text(component["label"], scope))
            multiple = component["variant"] == "multipleSelection"
            chips = component["displayStyle"] == "chips"
            control = if component["filterable"] == true
                        choice_combobox(choice, multiple, scope, renderer)
                      elsif multiple
                        choice_boxes(choice, chips, scope, renderer)
                      else
                        attributes = keyed(component, scope, renderer,
                                           { label: choice.label, value: choice.selected.first })
                        attributes[:orientation] = :horizontal if chips
                        attributes[:name] = renderer.input_name(choice.path, scope) if choice.path
                        renderer.component(Poetry::Ui::RadioGroup::Component, attributes) do |group|
                          choice.options.each do |option|
                            group.with_item(label: renderer.text(option["label"], scope), value: option["value"].to_s)
                          end
                          nil
                        end
                      end
            with_error(component, scope, renderer, control)
          end

          def choice_combobox(choice, multiple, scope, renderer)
            attributes = { multiple: multiple, placeholder: choice.label, aria: { label: choice.label },
                           value: multiple ? choice.selected : choice.selected.first }
            attributes[:name] = renderer.input_name(choice.path, scope) if choice.path
            renderer.component(Poetry::Ui::Combobox::Component, attributes) do |combobox|
              choice.options.each do |option|
                combobox.with_item(value: option["value"].to_s) { renderer.text(option["label"], scope) }
              end
              nil
            end
          end

          # A checkbox per option under one list name; the leading empty
          # value keeps "nothing checked" submittable. Chips wrap the row.
          def choice_boxes(choice, chips, scope, renderer)
            name = choice.path && "#{renderer.input_name(choice.path, scope)}[]"
            items = [renderer.view.tag.legend(choice.label, class: "mb-2 text-sm font-medium")]
            items << renderer.view.hidden_field_tag(name, "", id: nil) if name
            choice.options.each do |option|
              value = option["value"].to_s
              attributes = { label: renderer.text(option["label"], scope), value: value,
                             checked: choice.selected.include?(value) }
              attributes[:name] = name if name
              box = renderer.component(Poetry::Ui::Checkbox::Component, attributes, suffix: value)
              items << (chips ? renderer.view.tag.span(box, class: "rounded-full border px-3 py-1") : box)
            end
            classes = chips ? "flex flex-row flex-wrap items-center gap-2 [&>legend]:w-full" : "flex flex-col gap-2"
            renderer.view.tag.fieldset(renderer.view.safe_join(items), class: classes)
          end

          def render_slider(component, scope, renderer)
            path = binding_path(component["value"])
            min = component["min"].is_a?(Numeric) ? component["min"] : 0
            max = component["max"].is_a?(Numeric) ? component["max"] : 100
            value = renderer.resolve(component["value"], scope)
            label = renderer.text(component["label"], scope)
            label = renderer.aria_label(component, scope) || component["id"].to_s.tr("_", " ") if label.empty?
            attributes = { label: label, min: min, max: max, value: value.is_a?(Numeric) ? value : min }
            attributes[:name] = renderer.input_name(path, scope) if path
            steps = component["steps"]
            attributes[:step] = step_size(min, max, steps) if steps.is_a?(Integer) && steps.positive?
            keyed(component, scope, renderer, attributes)
            with_error(component, scope, renderer, renderer.component(Poetry::Ui::Slider::Component, attributes))
          end

          def step_size(min, max, steps)
            size = (max - min).to_f / steps
            size == size.floor ? size.to_i : size
          end

          def render_date_time_input(component, scope, renderer)
            path = binding_path(component["value"])
            type = if component["enableTime"] && component["enableDate"] then "datetime-local"
                   elsif component["enableTime"] then "time"
                   else "date"
                   end
            attributes = { id: renderer.control_id(component, scope), type: type,
                           value: renderer.text(component["value"], scope) }
            attributes[:name] = renderer.input_name(path, scope) if path
            %w[min max].each do |bound|
              limit = renderer.text(component[bound], scope)
              attributes[bound.to_sym] = limit unless limit.empty?
            end
            attributes[:required] = true if check_attributes(component)[:required]
            keyed(component, scope, renderer, attributes)
            with_error(component, scope, renderer, renderer.component(Poetry::Ui::Input::Component, attributes))
          end

          # The checks the browser can enforce as constraint attributes.
          def check_attributes(component)
            attributes = {}
            Array(component["checks"]).each do |check|
              condition = check.is_a?(Hash) ? check["condition"] : nil
              next unless condition.is_a?(Hash) && condition["call"]

              args = condition["args"].is_a?(Hash) ? condition["args"] : {}
              case condition["call"]
              when "required" then attributes[:required] = true
              when "regex" then attributes[:pattern] = args["pattern"] if args["pattern"].is_a?(String)
              when "length"
                attributes[:minlength] = args["min"] if args["min"].is_a?(Integer)
                attributes[:maxlength] = args["max"] if args["max"].is_a?(Integer)
              when "email" then attributes[:type] = :email
              when "numeric" then attributes[:inputmode] = "decimal"
              end
            end
            attributes
          end

          def binding_path(value)
            value.is_a?(Hash) && value["path"].is_a?(String) ? value["path"] : nil
          end
        end
      end
    end
  end
end
