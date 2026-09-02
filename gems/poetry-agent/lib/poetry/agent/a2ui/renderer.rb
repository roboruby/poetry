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
        # The Stimulus controller that runs a surface's checks as the user types.
        SURFACE_CONTROLLER = "poetry--agent--a2ui-surface"
        # The form events that re-run the checks.
        EVALUATE_ACTIONS = "input->#{SURFACE_CONTROLLER}#evaluate change->#{SURFACE_CONTROLLER}#evaluate".freeze

        # @return [Surface]
        attr_reader :surface
        # @return [Object] the view context
        attr_reader :view
        # @return [String, nil]
        attr_reader :action_url
        # @return [Array<String>] what could not be rendered, in render order
        attr_reader :warnings
        # @return [Hash{String => Array<Hash>}] check failures by component key (see {Surface#failures})
        attr_reader :errors

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
        # @param errors [Hash{String => Array<Hash>}] check failures to show, by
        #   component key (a rejected action's `errors`)
        def initialize(surface, view:, action_url: nil, html: {}, errors: {})
          @surface = surface
          @view = view
          @action_url = action_url
          @html = html
          @errors = errors || {}
          @warnings = []
        end

        # @return [String] the surface's HTML (html_safe)
        def call
          body = Poetry::Core::StableId.with_seed("a2ui:#{surface.id}") do
            surface.root ? render_component("root", nil) : blank
          end
          data = { a2ui_surface: surface.id, version: surface.version }.merge(@html[:data] || {})
          attributes = { id: self.class.element_id(surface), data: data }.merge(@html.except(:data))
          return view.tag.div(body, **attributes) unless action_url

          program = surface.program
          if program["checks"].any?
            data[:controller] = [data[:controller], SURFACE_CONTROLLER].compact.join(" ")
            data[:"#{SURFACE_CONTROLLER}-program-value"] = JSON.generate(program)
            data[:action] = [data[:action], EVALUATE_ACTIONS].compact.join(" ")
          end
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

          previous = @current_key
          @current_key = surface.source_key(component, scope)
          surface.catalog.render(component, scope, self) || blank
        rescue *COMPONENT_ERRORS, Poetry::Core::Error => e
          warn("#{component["component"]} #{component_id.inspect}: #{e.message}")
        ensure
          @current_key = previous
        end

        # Renders a child reference (an id, an id list, or a template).
        #
        # @param reference [String, Array<String>, Hash, nil]
        # @param scope [String, nil]
        # @return [String]
        def render_children(reference, scope = nil)
          view.safe_join(surface.expand(reference, scope).map { |id, child_scope| render_component(id, child_scope) })
        end

        # Builds and renders a library component. Every instance gets a
        # render-stable `key:` (the surface, the component, its scope, and
        # a suffix for repeated instances), so Turbo morph pairs the same
        # logical element across updates and local state survives.
        #
        # @param klass [Class] the component class
        # @param attributes [Hash] constructor keywords
        # @param suffix [String, nil] distinguishes several instances of one class for one component
        # @param keywords [Hash] constructor keywords given keyword-style (merged into `attributes`)
        # @yield the content block (the component instance is yielded)
        # @return [String]
        def component(klass, attributes = {}, suffix: nil, **keywords, &)
          attributes = attributes.merge(keywords)
          attributes = { key: stable_key(suffix) }.merge(attributes) unless attributes.key?(:key)
          view.render(klass.new(**attributes), &)
        end

        # @param suffix [String, nil]
        # @return [String] the render-stable key of the component being rendered
        def stable_key(suffix = nil)
          ["a2ui", surface.id, @current_key, suffix].compact.join("-")
        end

        # @return [String, nil] the key of the component being rendered (`id`, or `id@scope`)
        attr_reader :current_key

        # The display string of a dynamic value; a function problem warns.
        #
        # @param value [Object]
        # @param scope [String, nil]
        # @return [String]
        def text(value, scope = nil)
          surface.text(value, scope, on_error: method(:warn))
        end

        # @param value [Object]
        # @param scope [String, nil]
        # @return [Object, nil] the resolved dynamic value
        def resolve(value, scope = nil)
          surface.resolve(value, scope, on_error: method(:warn))
        end

        # Calls a catalog function; a problem warns and returns nil.
        #
        # @param name [String]
        # @param args [Hash, nil]
        # @param scope [String, nil]
        # @return [Object, nil]
        def call_function(name, args, scope = nil)
          Evaluator.new(surface, scope, on_error: method(:warn)).call(name, args)
        end

        # @param component [Hash]
        # @param scope [String, nil]
        # @return [String, nil] the first check failure message for the component
        def error_for(component, scope = nil)
          failure = Array(errors[surface.source_key(component, scope)]).first
          failure && failure[:message]
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

          { type: :submit, name: ACTION_PARAM, value: surface.source_key(component, scope) }
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
