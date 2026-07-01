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
    #   # => #<Poetry::Core::CSS::Merger:0x00007f8b1c0a3b40>
    #
    # @example Modifying global configuration
    #   Poetry::Core::Config.current.raise_on_asset_not_found = false
    #
    # @example Creating a custom configuration instance
    #   config = Poetry::Core::Config.new
    #   config.classname_merger = MyCustomMerger.new
    #
    # @example Using hash-style access
    #   Poetry::Core::Config.current[:classname_merger]
    #   Poetry::Core::Config.current[:custom_setting] = "value"
    #
    # @see Poetry::Core::CSS::Merger
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
        # @return [ActiveSupport::OrderedOptions] Hash-like object containing default configuration
        #
        # @option defaults [Poetry::Core::CSS::Merger] :classname_merger
        #   Merger instance for intelligently combining Tailwind CSS classes while
        #   resolving conflicts. Used throughout Poetry::Core components to handle CSS class merging.
        #
        # @option defaults [Poetry::Core::Stimulus::Merger] :stimulus_merger
        #   Merger instance for combining Stimulus controller data attributes without
        #   duplicating controllers or actions. Used when components need to merge
        #   Stimulus attributes from multiple sources.
        #
        # @option defaults [Boolean] :raise_on_asset_not_found (true)
        #   When true, raises an error if a referenced asset (JavaScript, CSS, etc.)
        #   cannot be found. Set to false for more lenient behavior in development.
        #
        # @example Getting default values
        #   defaults = Poetry::Core::Config.defaults
        #   defaults.classname_merger # => #<Poetry::Core::CSS::Merger:0x00007f8b1c0a3b40>
        #   defaults.raise_on_asset_not_found # => true
        def defaults
          ActiveSupport::OrderedOptions.new.merge!({
                                                     classname_merger: Poetry::Core::CSS::Merger.new,
                                                     stimulus_merger: Poetry::Core::Stimulus::Merger.new,
                                                     raise_on_asset_not_found: true,
                                                     # :tailwind emits resolved utility classes (default);
                                                     # :bem emits the BEM token IR for bring-your-own-CSS
                                                     # hosts (no:both, deliberately).
                                                     css_mode: :tailwind
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
        #   Poetry::Core::Config.current.raise_on_asset_not_found
        #   # => true
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
      #   @return [Poetry::Core::CSS::Merger] The CSS class merger instance
      #
      # @!method classname_merger=(merger)
      #   @param merger [Poetry::Core::CSS::Merger] The CSS class merger instance to use
      #   @return [Poetry::Core::CSS::Merger]
      #
      # @!method stimulus_merger
      #   @return [Poetry::Core::Stimulus::Merger] The Stimulus attribute merger instance
      #
      # @!method stimulus_merger=(merger)
      #   @param merger [Poetry::Core::Stimulus::Merger] The Stimulus attribute merger instance to use
      #   @return [Poetry::Core::Stimulus::Merger]
      #
      # @!method raise_on_asset_not_found
      #   @return [Boolean] Whether to raise errors when assets are not found
      #
      # @!method raise_on_asset_not_found=(value)
      #   @param value [Boolean] Whether to raise errors when assets are not found
      #   @return [Boolean]

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
      #   config.raise_on_asset_not_found = false
      #   Poetry::Core::Config.current.raise_on_asset_not_found # => true (unchanged)
      def initialize
        @config = self.class.defaults.clone
      end
    end
  end
end
