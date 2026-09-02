# frozen_string_literal: true

require "erb"
require_relative "pointer"
require_relative "markdown"

module Poetry
  module Agent
    module A2UI
      # Renders one {Surface} to HTML through the host's view context,
      # dispatching each component to the surface's catalog binding. The
      # surface becomes a form when an `action_url` is given: bound inputs
      # are named by their absolute data-model pointer and every agent
      # action is a submit button, so a user action posts the surface's
      # current inputs plus the source component - the spec's "inputs sync
      # only on an action" contract, in Hotwire's native shape. The
      # wrapper carries the surface's version for the versioned Turbo
      # Stream replace.
      #
      # Rendering never raises for an agent's mistake: an unknown
      # component, a dangling reference, a component the library refuses
      # to build, or an unsupported function renders nothing and lands in
      # {#warnings}.
      #
      # @example
      #   renderer = Renderer.new(surface, view: view_context, action_url: "/a2ui/action")
      #   html = renderer.call
      #   renderer.warnings # => []
      class Renderer
        # The DOM id prefix of a rendered surface.
        ELEMENT_PREFIX = "a2ui-"
        # The parameter carrying the bound values, keyed by absolute pointer.
        VALUES_PARAM = "a2ui[values]"
        # The parameter carrying the source component of the action.
        ACTION_PARAM = "a2ui[action]"
        # The parameter carrying the surface id.
        SURFACE_PARAM = "a2ui[surface]"
        # The errors an agent-authored component may provoke in the library.
        COMPONENT_ERRORS = [ArgumentError, NameError].freeze

        # @return [Surface]
        attr_reader :surface
        # @return [Object] the view context
        attr_reader :view
        # @return [String, nil]
        attr_reader :action_url
        # @return [Array<String>] what could not be rendered, in render order
        attr_reader :warnings

        # @param surface_or_id [Surface, String]
        # @return [String] the DOM id of the surface's wrapper
        def self.element_id(surface_or_id)
          id = surface_or_id.respond_to?(:id) ? surface_or_id.id : surface_or_id
          "#{ELEMENT_PREFIX}#{id}"
        end

        # @param surface [Surface]
        # @param view [Object] an ActionView context (`view_context`)
        # @param action_url [String, nil] where actions post; nil renders a plain container
        # @param html [Hash] extra attributes for the wrapper (`class:` etc.)
        def initialize(surface, view:, action_url: nil, html: {})
          @surface = surface
          @view = view
          @action_url = action_url
          @html = html
          @warnings = []
        end

        # @return [String] the surface's HTML (html_safe)
        def call
          body = surface.root ? render_component("root", nil) : blank
          data = { a2ui_surface: surface.id, version: surface.version }.merge(@html[:data] || {})
          attributes = { id: self.class.element_id(surface), data: data }.merge(@html.except(:data))
          return view.tag.div(body, **attributes) unless action_url

          view.form_with(url: action_url, method: :post, **attributes) do
            view.safe_join([view.hidden_field_tag(SURFACE_PARAM, surface.id, id: nil), body])
          end
        end

        # @param component_id [String]
        # @param scope [String, nil]
        # @return [String] the component's HTML (empty when it cannot render)
        def render_component(component_id, scope = nil)
          component = surface.component(component_id)
          return warn("unknown component id #{component_id.inspect}") unless component

          surface.catalog.render(component, scope, self) || blank
        rescue *COMPONENT_ERRORS, Poetry::Core::Error => e
          warn("#{component["component"]} #{component_id.inspect}: #{e.message}")
        end

        # Renders a child reference (an id, an id list, or a template).
        #
        # @param reference [String, Array<String>, Hash, nil]
        # @param scope [String, nil]
        # @return [String]
        def render_children(reference, scope = nil)
          view.safe_join(surface.expand(reference, scope).map { |id, child_scope| render_component(id, child_scope) })
        end

        # Builds and renders a library component, or warns.
        #
        # @param klass [Class] the component class
        # @param attributes [Hash] constructor keywords
        # @yield the content block (the component instance is yielded)
        # @return [String]
        def component(klass, attributes = {}, &)
          view.render(klass.new(**attributes), &)
        end

        # The display string of a dynamic value; a function call warns.
        #
        # @param value [Object]
        # @param scope [String, nil]
        # @return [String]
        def text(value, scope = nil)
          if surface.function_call?(value)
            warn("function #{value["call"].inspect} is not supported by this renderer")
            return ""
          end

          surface.text(value, scope)
        end

        # @param value [Object]
        # @param scope [String, nil]
        # @return [Object, nil] the resolved dynamic value
        def resolve(value, scope = nil)
          return text(value, scope) if surface.function_call?(value)

          surface.resolve(value, scope)
        end

        # @param path [String] a bound pointer
        # @param scope [String, nil]
        # @return [String] the input's form name
        def input_name(path, scope = nil)
          "#{VALUES_PARAM}[#{Pointer.absolute(path, scope)}]"
        end

        # @param component [Hash]
        # @param scope [String, nil]
        # @return [String] a DOM id for the component's control
        def control_id(component, scope = nil)
          suffix = scope ? "-#{scope.delete_prefix("/").tr("/", "-")}" : ""
          "#{self.class.element_id(surface)}-#{component["id"]}#{suffix}"
        end

        # The attributes that make a button an agent action.
        #
        # @param component [Hash]
        # @param scope [String, nil]
        # @return [Hash]
        def submit_attributes(component, scope = nil)
          return { type: :button } unless action_url

          { type: :submit, name: ACTION_PARAM, value: scope ? "#{component["id"]}@#{scope}" : component["id"] }
        end

        # @param component [Hash]
        # @param scope [String, nil]
        # @return [String, nil] the component's accessibility label
        def aria_label(component, scope = nil)
          accessibility = component["accessibility"]
          return unless accessibility.is_a?(Hash) && accessibility["label"]

          label = text(accessibility["label"], scope)
          label.empty? ? nil : label
        end

        # @param text [String]
        # @return [String] the Markdown subset rendered (html_safe)
        def markdown(text)
          Markdown.render(text).html_safe
        end

        # @return [String] an empty html_safe string
        def blank
          view.safe_join([])
        end

        # Records a problem and renders nothing for it.
        #
        # @param message [String]
        # @return [String] an empty html_safe string
        def warn(message)
          @warnings << message
          blank
        end
      end
    end
  end
end
