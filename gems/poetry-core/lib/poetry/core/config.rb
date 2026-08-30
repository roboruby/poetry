# frozen_string_literal: true

module Poetry
  module Core
    # Manages configuration settings for the Poetry::Core module.
    #
    # This class provides a flexible configuration system using ActiveSupport::OrderedOptions
    # under the hood, allowing access to configuration values using either hash-style or
    # method-style syntax. It supports both a singleton pattern via {.current} for global
    # configuration and the ability to create custom configuration instances.
    #
    # The configuration system is designed to be easily extensible while providing sensible
    # defaults for all Poetry::Core components.
    #
    # @example Accessing global configuration
    #   Poetry::Core::Config.current.classname_merger
    #   # => #<Poetry::Core::CSS::TailwindMerger:0x00007f8b1c0a3b40>
    #
    # @example Modifying global configuration
    #   Poetry::Core::Config.current.icon_library = :my_icons
    #
    # @example Creating a custom configuration instance
    #   config = Poetry::Core::Config.new
    #   config.classname_merger = MyCustomMerger.new
    #
    # @example Using hash-style access
    #   Poetry::Core::Config.current[:classname_merger]
    #   Poetry::Core::Config.current[:custom_setting] = "value"
    #
    # @see Poetry::Core::CSS::TailwindMerger
    # @see Poetry::Core::Stimulus::Merger
    class Config
      class << self
        # Creates a new configuration instance with default settings.
        #
        # This is aliased from the standard {#initialize} method to provide a more
        # semantic way to create default configurations.
        #
        # @return [Poetry::Core::Config] A new configuration instance with default values
        # @example
        #   config = Poetry::Core::Config.default
        alias default new

        # Returns the default configuration values.
        #
        # These defaults are used when initializing new configuration instances and
        # define the standard behavior for all Poetry::Core components.
        #
        # The keys and their defaults:
        #
        # - `classname_merger` ({Poetry::Core::CSS::TailwindMerger}) - resolves
        #   conflicting utility classes when caller classes meet component
        #   classes.
        # - `stimulus_merger` ({Poetry::Core::Stimulus::Merger}) - combines
        #   Stimulus data attributes without duplicating controllers or
        #   actions.
        # - `css_mode` (`:tailwind`) - `:tailwind` emits resolved utility
        #   classes; `:bem` emits the BEM token IR for bring-your-own-CSS
        #   hosts.
        # - `icon_library` (`:lucide`) - the active icon set, by the key it
        #   registered under ({Poetry::Core::Icons.register}).
        # - `raise_on_missing_icon` (`nil`) - the policy for a dynamic icon
        #   name that resolves to nothing: nil raises in local environments
        #   and degrades to the fallback elsewhere; true/false force one
        #   behavior.
        # - `icon_fallback` (`:"circle-question-mark"`) - rendered instead
        #   of a missing icon when not raising; nil re-raises.
        # - `on_missing_icon` (`nil`) - an optional callable
        #   `(name:, library:, error:)` fired before the fallback renders.
        # - `stable_id_mode` (`:off`) - the opt-in `:sequence` mode seeds a
        #   per-request deterministic id sequence (read the hazards in
        #   StableId before enabling).
        # - `stable_id_seed` - the request-to-seed callable for that mode
        #   (defaults to the request path).
        #
        # @return [ActiveSupport::OrderedOptions] the default configuration
        #
        # @example Getting default values
        #   defaults = Poetry::Core::Config.defaults
        #   defaults.classname_merger # => #<Poetry::Core::CSS::TailwindMerger:0x00007f8b1c0a3b40>
        #   defaults.css_mode # => :tailwind
        def defaults
          ActiveSupport::OrderedOptions.new.merge!({
                                                     classname_merger: Poetry::Core::CSS::TailwindMerger.new,
                                                     stimulus_merger: Poetry::Core::Stimulus::Merger.new,
                                                     # :tailwind emits resolved utility classes (default);
                                                     # :bem emits the BEM token IR for bring-your-own-CSS
                                                     # hosts (no :both, deliberately).
                                                     css_mode: :tailwind,
                                                     # The active icon set (Lucide default; sets
                                                     # register via Poetry::Core::Icons.register).
                                                     icon_library: :lucide,
                                                     # The missing-icon policy. Static literals
                                                     # are caught by poetry check; a DYNAMIC name (a DB
                                                     # value, a user setting) surfaces at render. nil =
                                                     # auto: raise in Rails.env.local?, degrade to
                                                     # icon_fallback elsewhere. true/false force it.
                                                     raise_on_missing_icon: nil,
                                                     # StableId sequence mode (OPT-IN, experimental):
                                                     # :off (default) or :sequence - the engine's
                                                     # around_action seeds a per-request deterministic
                                                     # id sequence. Read the hazards in StableId before
                                                     # enabling; keyed identity (key:) is the general
                                                     # answer, this mode is for byte-stable content
                                                     # pages only.
                                                     stable_id_mode: :off,
                                                     stable_id_seed: ->(request) { request.path }, # rubocop:disable Style/SymbolProc -- the documented override shape
                                                     # Rendered instead of a missing icon when not
                                                     # raising; nil re-raises. Must exist in every
                                                     # registered set (Lucide ships it).
                                                     icon_fallback: :"circle-question-mark",
                                                     # Optional callable(name:, library:, error:) fired
                                                     # before the fallback renders - the instrumentation
                                                     # seam (log, notify, count). Fires per render.
                                                     on_missing_icon: nil
                                                   })
        end

        # Returns the global singleton configuration instance.
        #
        # This method provides access to the shared configuration used throughout the
        # application. The instance is created lazily on first access and persists for
        # the lifetime of the application.
        #
        # @return [Poetry::Core::Config] The global configuration instance
        #
        # @example Accessing global settings
        #   Poetry::Core::Config.current.css_mode
        #   # => :tailwind
        #
        # @example Modifying global settings
        #   Poetry::Core::Config.current.classname_merger = CustomMerger.new
        #
        # @note Changes to the global configuration will affect all Poetry::Core components
        #   throughout the application.
        def current
          @current ||= default
        end
      end

      # @!method classname_merger
      #   The merger that resolves conflicting utility classes when caller
      #   classes meet component classes.
      #   @return [Poetry::Core::CSS::TailwindMerger] The CSS class merger instance
      #
      # @!method classname_merger=(merger)
      #   Replaces the class merger.
      #   @param merger [Poetry::Core::CSS::TailwindMerger] The CSS class merger instance to use
      #   @return [Poetry::Core::CSS::TailwindMerger]
      #
      # @!method stimulus_merger
      #   The merger that combines Stimulus data attributes without
      #   duplicating controllers or actions.
      #   @return [Poetry::Core::Stimulus::Merger] The Stimulus attribute merger instance
      #
      # @!method stimulus_merger=(merger)
      #   Replaces the Stimulus attribute merger.
      #   @param merger [Poetry::Core::Stimulus::Merger] The Stimulus attribute merger instance to use
      #   @return [Poetry::Core::Stimulus::Merger]
      #
      # @!method css_mode
      #   The class emission mode: `:tailwind` resolves style values to
      #   utility classes, `:bem` emits the BEM token IR.
      #   @return [Symbol] :tailwind or :bem
      #
      # @!method css_mode=(mode)
      #   Sets the class emission mode.
      #   @param mode [Symbol] :tailwind or :bem
      #   @return [Symbol]
      #
      # @!method icon_library
      #   The key of the active icon set ({Poetry::Core::Icons.register}).
      #   @return [Symbol]
      #
      # @!method icon_library=(key)
      #   Selects the active icon set.
      #   @param key [Symbol, String] a registered library key
      #   @return [Symbol, String]
      #
      # @!method raise_on_missing_icon
      #   The policy for a dynamic icon name that resolves to nothing: nil
      #   raises in local environments and degrades to the fallback
      #   elsewhere; true/false force one behavior.
      #   @return [Boolean, nil]
      #
      # @!method raise_on_missing_icon=(policy)
      #   Sets the missing-icon policy.
      #   @param policy [Boolean, nil]
      #   @return [Boolean, nil]
      #
      # @!method icon_fallback
      #   The icon rendered instead of a missing one when not raising; nil
      #   re-raises. Must exist in every registered set.
      #   @return [Symbol, nil]
      #
      # @!method icon_fallback=(name)
      #   Sets the fallback icon.
      #   @param name [Symbol, nil]
      #   @return [Symbol, nil]
      #
      # @!method on_missing_icon
      #   The instrumentation hook fired before a fallback icon renders,
      #   called with `name:`, `library:`, and `error:`.
      #   @return [#call, nil]
      #
      # @!method on_missing_icon=(callable)
      #   Sets the missing-icon hook.
      #   @param callable [#call, nil]
      #   @return [#call, nil]
      #
      # @!method stable_id_mode
      #   The StableId sequence mode: `:off`, or the opt-in `:sequence`.
      #   @return [Symbol]
      #
      # @!method stable_id_mode=(mode)
      #   Sets the StableId sequence mode.
      #   @param mode [Symbol] :off or :sequence
      #   @return [Symbol]
      #
      # @!method stable_id_seed
      #   The request-to-seed callable the `:sequence` mode derives its
      #   per-request id sequence from.
      #   @return [#call]
      #
      # @!method stable_id_seed=(callable)
      #   Sets the seed callable.
      #   @param callable [#call] receives the request, returns the seed
      #   @return [#call]

      # The declared configuration surface: every key {.defaults} ships.
      # Each is a real reader/writer pair (delegated just below); unknown
      # keys still flow through delegate_missing_to, so hosts may stash
      # their own values.
      SETTINGS = %i[classname_merger stimulus_merger css_mode icon_library
                    raise_on_missing_icon icon_fallback on_missing_icon
                    stable_id_mode stable_id_seed].freeze

      delegate(*SETTINGS, *SETTINGS.map { |key| :"#{key}=" }, to: :@config)

      # Delegates all method calls to the internal configuration object.
      #
      # This allows the Config instance to act as a transparent wrapper around
      # ActiveSupport::OrderedOptions, supporting both method-style and hash-style
      # access to configuration values.
      #
      # @api private
      delegate_missing_to :@config

      # Initializes a new configuration instance with default values.
      #
      # The new instance gets a clone of the default configuration, ensuring each
      # configuration object is independent and modifications won't affect the defaults
      # or other instances.
      #
      # @return [Poetry::Core::Config] A new configuration instance
      #
      # @example Creating an isolated configuration
      #   config = Poetry::Core::Config.new
      #   config.css_mode = :bem
      #   Poetry::Core::Config.current.css_mode # => :tailwind (unchanged)
      def initialize
        @config = self.class.defaults.clone
      end
    end
  end
end
