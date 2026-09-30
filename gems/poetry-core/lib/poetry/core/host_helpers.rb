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
      # Prepended to Action View's base class by the engine: the first view
      # context of a host that did not eager load syncs the helpers, so the
      # template about to render can call one. After that it is one
      # comparison per view.
      #
      # @api private
      module FirstView
        # The view context, with the helpers defined first.
        def initialize(...)
          Poetry::Core::HostHelpers.sync_now! unless Poetry::Core::HostHelpers.ready?
          super
        end
      end

      SYNC = Mutex.new
      private_constant :SYNC

      class << self
        # Discovers the app's components and defines their helpers: the
        # engine's sync, at the end of an eager loading boot, at the first
        # view otherwise, and on every reload. One at a time, since two views
        # can be the first on two threads.
        #
        # @return [Array<String>] the helper names now defined
        def sync_now!
          SYNC.synchronize do
            names = sync!(HostComponents.discover)
            @ready = true
            names
          end
        end

        # Whether the first sync has happened, so a reload may sync again.
        #
        # @return [Boolean]
        def ready?
          @ready == true
        end

        # Defines the helpers of `components` and removes the helpers of
        # components that no longer declare one (a rename, a deletion).
        # Every name is checked before any is defined, so a clash leaves
        # the module exactly as it was and the next reload starts clean.
        #
        # @param components [Enumerable<Class>] the app's component classes
        # @return [Array<String>] the helper names now defined
        # @raise [Poetry::Core::Error] when a declared name is already a
        #   view helper that is not one of these, or two components declare
        #   the same name
        def sync!(components)
          wanted = {}
          components.each do |component|
            name = component.helper_name
            next unless name

            if (other = wanted[name])
              raise Poetry::Core::Error,
                    "#{component.name} and #{other} both declare helper :#{name} - one helper name per component"
            end
            check!(name, component.name)
            wanted[name] = component.name
          end
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

        # Raises when a declared helper name is already taken by a view helper the module does not own.
        # @api private
        def check!(name, class_name)
          return if owned.include?(name) || !taken?(name)

          raise Poetry::Core::Error,
                "#{class_name} declares helper :#{name}, but a view helper named #{name} already exists " \
                "(#{owner_of(name)}) - choose a name no gem or app helper uses"
        end

        # Defines the view helper that renders the component class.
        # @api private
        def define(name, class_name)
          define_method(name) do |**attrs, &block|
            render(Object.const_get(class_name).new(**attrs), &block)
          end
        end

        # Whether a view helper of that name exists outside this module:
        # Action View's own and included modules (public or private - a
        # private `format` or `raise` shadowed is a broken view), the app's
        # own helper modules (ApplicationHelper, `helper_method`), and
        # poetry-ui's helper module when the gem is present (its include
        # into Action View is deferred, so it may not be on the base class
        # yet at boot).
        def taken?(name)
          !owner_of(name).nil?
        end

        # Who defines the name, for the message; nil when nobody does.
        def owner_of(name)
          name = name.to_s
          if defined?(ActionView::Base) &&
             (ActionView::Base.method_defined?(name) || ActionView::Base.private_method_defined?(name))
            return "Action View"
          end
          if (app = app_helpers) && (app.method_defined?(name) || app.private_method_defined?(name))
            return "the app's helpers"
          end
          # archspec:disable-next-line constants.forbid -- a defined? probe, never a dependency
          if defined?(Poetry::Ui::ComponentsHelper) && Poetry::Ui::ComponentsHelper.method_defined?(name)
            return "poetry-ui"
          end

          nil
        end

        # The app's controller helper module, when the app defines
        # ApplicationController (autoloaded here, on purpose: the helpers it
        # gathers are the ones a view sees).
        def app_helpers
          controller = Object.const_get(:ApplicationController)
          controller.respond_to?(:_helpers) ? controller._helpers : nil
        rescue NameError, LoadError
          nil
        end
      end

      private_class_method :taken?, :owner_of, :app_helpers
    end
  end
end
