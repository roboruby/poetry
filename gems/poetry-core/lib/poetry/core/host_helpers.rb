# frozen_string_literal: true

module Poetry
  module Core
    # The view helpers of the host application's own components - one
    # method per `helper :name` declaration, defined here by the engine at
    # boot and again on every code reload, and included into Action View.
    # Each helper renders its component with the keywords it receives and
    # the block as content, exactly like the gems' own helpers. The class
    # is resolved by name at call time, so a reloaded class is the one
    # rendered.
    #
    # @example In a view, for `helper :demo_badge`
    #   <%= demo_badge(tone: :loud) { "New" } %>
    #
    # @api private
    module HostHelpers
      class << self
        # Defines the helpers of `components` and removes the helpers of
        # components that no longer declare one (a rename, a deletion).
        #
        # @param components [Enumerable<Class>] the app's component classes
        # @return [Array<String>] the helper names now defined
        # @raise [Poetry::Core::Error] when a declared name is already a
        #   view helper that is not one of these
        def sync!(components)
          wanted = components.filter_map do |component|
            [component.helper_name, component.name] if component.helper_name
          end.to_h
          (owned - wanted.keys).each { |name| remove_method(name) }
          wanted.each { |name, class_name| define(name, class_name) }
          @owned = wanted.keys
        end

        # The helper names this module currently defines.
        #
        # @return [Array<String>]
        def owned
          @owned ||= []
        end

        # @api private
        def define(name, class_name)
          if !owned.include?(name) && taken?(name)
            raise Poetry::Core::Error,
                  "#{class_name} declares helper :#{name}, but a view helper named #{name} already exists - " \
                  "choose a name no gem or app helper uses"
          end

          define_method(name) do |**attrs, &block|
            render(Object.const_get(class_name).new(**attrs), &block)
          end
        end

        # Whether a view helper of that name exists outside this module:
        # Action View's own and included modules, plus poetry-ui's helper
        # module when the gem is present (its include into Action View is
        # deferred, so it may not be on the base class yet at boot).
        def taken?(name)
          return true if defined?(ActionView::Base) && ActionView::Base.method_defined?(name)

          defined?(Poetry::Ui::ComponentsHelper) && Poetry::Ui::ComponentsHelper.method_defined?(name)
        end
      end
    end
  end
end
