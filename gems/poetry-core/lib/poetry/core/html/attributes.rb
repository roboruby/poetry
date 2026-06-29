# frozen_string_literal: true

module Poetry
  module Core
    # Adapted from https://github.com/jefawks3/fox_tail/blob/main/lib/fox_tail/html_attributes.rb
    module HTML
      # A specialized hash for managing HTML attributes with intelligent merging capabilities.
      #
      # This class extends ActiveSupport::HashWithIndifferentAccess to provide enhanced
      # functionality for handling HTML attributes, particularly CSS classes, Stimulus
      # controllers/actions, data attributes, and ARIA attributes.
      #
      # Features:
      # - Smart merging of CSS classes without duplication
      # - Intelligent merging of Stimulus controllers and actions
      # - Automatic flattening of nested data and aria attributes
      # - Proper handling of HTML boolean attributes
      # - Both mutating (!) and non-mutating versions of merge methods
      #
      # @example Basic usage
      #   attrs = Poetry::Core::HTML::Attributes.new(class: "btn", disabled: true)
      #   attrs.merge_classes!("btn-primary")
      #   attrs.to_attributes # => { "class" => "btn btn-primary", "disabled" => "disabled" }
      #
      # @example Merging Stimulus controllers
      #   attrs = Poetry::Core::HTML::Attributes.new
      #   attrs.merge_stimulus_controllers!("dropdown", "modal")
      #   attrs.to_attributes # => { "data-controller" => "dropdown modal" }
      #
      # @example Working with data attributes
      #   attrs = Poetry::Core::HTML::Attributes.new(data: { id: 1, name: "test" })
      #   attrs.to_attributes # => { "data-id" => "1", "data-name" => "test" }
      class Attributes < ActiveSupport::HashWithIndifferentAccess
        # List of HTML boolean attributes that should be rendered as attribute name only
        # when truthy, or omitted when falsy.
        #
        # @example
        #   attrs = Poetry::Core::HTML::Attributes.new(disabled: true, hidden: false)
        #   attrs.to_attributes # => { "disabled" => "disabled" }
        #   # Note: hidden is omitted because it's false
        BOOLEAN_ATTRIBUTES = %w[
          allowfullscreen allowpaymentrequest async autofocus autoplay checked compact controls declare default
          defaultchecked defaultmuted defaultselected defer disabled enabled formnovalidate hidden indeterminate
          inert ismap itemscope loop multiple muted nohref nomodule noresize noshade novalidate nowrap open
          pauseonexit playsinline readonly required reversed scoped seamless selected sortable truespeed
          typemustmatch visible
        ].freeze

        # Merges CSS classes into the attributes, returning a new instance.
        #
        # This non-mutating method creates a deep copy of the attributes and merges
        # the provided classnames intelligently, avoiding duplicates and handling
        # conditional classes.
        #
        # @param classnames [Array<String, Hash, Array>] One or more classnames to merge.
        #   Can be strings, hashes with conditional classes, or arrays.
        # @return [Poetry::Core::HTML::Attributes] A new instance with merged classes
        #
        # @example Merge simple classes
        #   attrs = Poetry::Core::HTML::Attributes.new(class: "btn")
        #   new_attrs = attrs.merge_classes("btn-primary", "btn-lg")
        #   new_attrs["class"] # => "btn btn-primary btn-lg"
        #   attrs["class"] # => "btn" (original unchanged)
        def merge_classes(*classnames)
          deep_dup.merge_classes!(*classnames)
        end

        # Merges CSS classes into the attributes, mutating the current instance.
        #
        # This mutating method modifies the current attributes object by merging
        # the provided classnames.
        #
        # @param classnames [Array<String, Hash, Array>] One or more classnames to merge
        # @return [Poetry::Core::HTML::Attributes] Self for method chaining
        #
        # @example Merge classes in place
        #   attrs = Poetry::Core::HTML::Attributes.new(class: "btn")
        #   attrs.merge_classes!("btn-primary")
        #   attrs["class"] # => "btn btn-primary"
        def merge_classes!(*classnames)
          self["class"] = config.classname_merger.merge(self["class"], *classnames)
          self
        end

        # Merges Stimulus controllers into the data-controller attribute, returning a new instance.
        #
        # @param controllers [Array<String, Hash>] One or more controller names or
        #   hashes with controller names and options
        # @return [Poetry::Core::HTML::Attributes] A new instance with merged controllers
        #
        # @example Merge controllers
        #   attrs = Poetry::Core::HTML::Attributes.new
        #   new_attrs = attrs.merge_stimulus_controllers("dropdown", "modal")
        #   new_attrs["data"]["controller"] # => "dropdown modal"
        def merge_stimulus_controllers(*controllers)
          deep_dup.merge_stimulus_controllers!(*controllers)
        end

        # Merges Stimulus controllers into the data-controller attribute, mutating the current instance.
        #
        # @param controllers [Array<String, Hash>] One or more controller names
        # @return [Poetry::Core::HTML::Attributes] Self for method chaining
        #
        # @example Merge controllers in place
        #   attrs = Poetry::Core::HTML::Attributes.new(data: { controller: "dropdown" })
        #   attrs.merge_stimulus_controllers!("modal")
        #   attrs["data"]["controller"] # => "dropdown modal"
        def merge_stimulus_controllers!(*controllers)
          self["data"] ||= {}
          self["data"]["controller"] = config.stimulus_merger.merge_controllers(dig("data", "controller"), *controllers)
          self
        end

        # Merges Stimulus actions into the data-action attribute, returning a new instance.
        #
        # @param actions [Array<String, Hash>] One or more action strings or hashes
        # @return [Poetry::Core::HTML::Attributes] A new instance with merged actions
        #
        # @example Merge actions
        #   attrs = Poetry::Core::HTML::Attributes.new
        #   new_attrs = attrs.merge_stimulus_actions("click->modal#open", "keydown->modal#close")
        #   new_attrs["data"]["action"] # => "click->modal#open keydown->modal#close"
        def merge_stimulus_actions(*actions)
          deep_dup.merge_stimulus_actions!(*actions)
        end

        # Merges Stimulus actions into the data-action attribute, mutating the current instance.
        #
        # @param actions [Array<String, Hash>] One or more action strings
        # @return [Poetry::Core::HTML::Attributes] Self for method chaining
        #
        # @example Merge actions in place
        #   attrs = Poetry::Core::HTML::Attributes.new(data: { action: "click->modal#open" })
        #   attrs.merge_stimulus_actions!("keydown->modal#close")
        #   attrs["data"]["action"] # => "click->modal#open keydown->modal#close"
        def merge_stimulus_actions!(*actions)
          self["data"] ||= {}
          self["data"]["action"] = config.stimulus_merger.merge_actions(dig("data", "action"), *actions)
          self
        end

        # Merges Stimulus data attributes, returning a new instance.
        #
        # This method intelligently merges data attributes, handling controllers,
        # actions, and other data attributes appropriately.
        #
        # @param stimulus_hash [Array<Hash>] One or more hashes of Stimulus data attributes
        # @yield [key, old_value, new_value] Optional block for custom merge logic
        # @return [Poetry::Core::HTML::Attributes] A new instance with merged Stimulus data
        #
        # @example Merge Stimulus attributes
        #   attrs = Poetry::Core::HTML::Attributes.new(data: { controller: "dropdown" })
        #   new_attrs = attrs.merge_stimulus({ action: "click->modal#open", target: "output" })
        #   new_attrs["data"] # => { "controller" => "dropdown", "action" => "click->modal#open", "target" => "output" }
        def merge_stimulus(*stimulus_hash, &)
          deep_dup.merge_stimulus!(*stimulus_hash, &)
        end

        # Merges Stimulus data attributes, mutating the current instance.
        #
        # @param stimulus_hash [Array<Hash>] One or more hashes of Stimulus data attributes
        # @yield [key, old_value, new_value] Optional block for custom merge logic
        # @return [Poetry::Core::HTML::Attributes] Self for method chaining
        #
        # @example Merge Stimulus attributes in place
        #   attrs = Poetry::Core::HTML::Attributes.new
        #   attrs.merge_stimulus!({ controller: "dropdown", action: "click->dropdown#toggle" })
        #   attrs["data"] # => { "controller" => "dropdown", "action" => "click->dropdown#toggle" }
        def merge_stimulus!(*stimulus_hash, &)
          self["data"] = config.stimulus_merger.merge(self["data"], *stimulus_hash, &)
          self
        end

        # Merges attributes only if they are not already set, returning a new instance.
        #
        # This method intelligently merges attributes by only adding keys that don't exist
        # in the current attributes. It handles both flat and nested data attributes:
        # - "data-controller" and data: { controller: "..." } are treated as the same
        # - "aria-label" and aria: { label: "..." } are treated as the same
        #
        # @param other_hash [Hash] Hash of attributes to merge if not set
        # @return [Poetry::Core::HTML::Attributes] A new instance with conditionally merged attributes
        #
        # @example Merge defaults that won't override user values
        #   attrs = Poetry::Core::HTML::Attributes.new(class: "btn", data: { controller: "dropdown" })
        #   defaults = { class: "btn-default", data: { action: "click->modal#open" }, id: "my-btn" }
        #   new_attrs = attrs.merge_if_not_set(defaults)
        #   # Result: class: "btn", data: { controller: "dropdown", action: "click->modal#open" }, id: "my-btn"
        #   # Note: "btn-default" not added because class was already set
        #   # Note: action added because it wasn't set, but controller kept original value
        def merge_if_not_set(other_hash)
          deep_dup.merge_if_not_set!(other_hash)
        end

        # Merges attributes only if they are not already set, mutating the current instance.
        #
        # @param other_hash [Hash] Hash of attributes to merge if not set
        # @return [Poetry::Core::HTML::Attributes] Self for method chaining
        #
        # @example Set defaults without overriding
        #   attrs = Poetry::Core::HTML::Attributes.new(data: { controller: "dropdown" })
        #   attrs.merge_if_not_set!(class: "btn", data: { controller: "modal", action: "click->dropdown#toggle" })
        #   # Result: class: "btn", data: { controller: "dropdown", action: "click->dropdown#toggle" }
        def merge_if_not_set!(other_hash)
          other_hash = convert_value(other_hash)

          # First, normalize any flat data/aria attributes in self to nested format
          normalize_flat_attributes!

          other_hash.each do |key, value|
            if key.to_s == "data" && value.is_a?(Hash)
              # Handle nested data attributes
              merge_data_if_not_set!(value)
            elsif key.to_s == "aria" && value.is_a?(Hash)
              # Handle nested aria attributes
              merge_aria_if_not_set!(value)
            elsif key.to_s.start_with?("data-")
              # Handle flat data attributes like "data-controller"
              nested_key = key.to_s.delete_prefix("data-").underscore
              set_if_not_present!("data", nested_key, value)
            elsif key.to_s.start_with?("aria-")
              # Handle flat aria attributes like "aria-label"
              nested_key = key.to_s.delete_prefix("aria-").underscore
              set_if_not_present!("aria", nested_key, value)
            elsif !has_attribute?(key)
              # Only set if the attribute doesn't exist at all
              self[key] = value
            end
          end

          self
        end

        # Checks if an attribute is set, handling both flat and nested formats.
        #
        # This method is smart about data and aria attributes, checking both
        # the nested and flat formats.
        #
        # @param key [String, Symbol] The attribute key to check
        # @param nested_key [String, Symbol, nil] Optional nested key for data/aria attributes
        # @return [Boolean] True if the attribute exists
        #
        # @example Check for regular attributes
        #   attrs = Poetry::Core::HTML::Attributes.new(class: "btn", id: "my-btn")
        #   attrs.has_attribute?(:class) # => true
        #   attrs.has_attribute?(:disabled) # => false
        #
        # @example Check for data attributes (nested format)
        #   attrs = Poetry::Core::HTML::Attributes.new(data: { controller: "dropdown" })
        #   attrs.has_attribute?("data", "controller") # => true
        #   attrs.has_attribute?("data", "action") # => false
        #
        # @example Check for data attributes (flat format)
        #   attrs = Poetry::Core::HTML::Attributes.new("data-controller" => "dropdown")
        #   attrs.has_attribute?("data", "controller") # => true
        def has_attribute?(key, nested_key = nil)
          if nested_key
            # Check nested format: data: { controller: "..." }
            return true if dig(key, nested_key).present?

            # Check flat format: "data-controller" => "..."
            flat_key = "#{key}-#{nested_key.to_s.dasherize}"
            return true if self[flat_key].present?

            false
          else
            # For simple attributes, check if key exists
            key?(key)
          end
        end

        # Gets an attribute value, handling both flat and nested formats.
        #
        # @param key [String, Symbol] The attribute key
        # @param nested_key [String, Symbol, nil] Optional nested key for data/aria attributes
        # @return [Object, nil] The attribute value or nil if not found
        #
        # @example Get nested data attribute
        #   attrs = Poetry::Core::HTML::Attributes.new(data: { controller: "dropdown" })
        #   attrs.get_attribute("data", "controller") # => "dropdown"
        #
        # @example Get flat data attribute
        #   attrs = Poetry::Core::HTML::Attributes.new("data-controller" => "dropdown")
        #   attrs.get_attribute("data", "controller") # => "dropdown"
        def get_attribute(key, nested_key = nil)
          if nested_key
            # Try nested format first
            value = dig(key, nested_key)
            return value if value.present?

            # Try flat format
            flat_key = "#{key}-#{nested_key.to_s.dasherize}"
            self[flat_key]
          else
            self[key]
          end
        end

        # Converts the attributes hash to a flat hash suitable for HTML rendering.
        #
        # This method performs several transformations:
        # - Flattens nested data attributes (data: { id: 1 } => "data-id" => "1")
        # - Flattens nested aria attributes (aria: { label: "Close" } => "aria-label" => "Close")
        # - Handles boolean attributes (disabled: true => "disabled" => "disabled")
        # - Skips nil values for all attributes
        # - Converts complex values to JSON strings when appropriate
        #
        # @return [Hash<String, String>] A flat hash of HTML attribute names to values
        #
        # @example Convert to HTML attributes
        #   attrs = Poetry::Core::HTML::Attributes.new(
        #     class: "btn btn-primary",
        #     disabled: true,
        #     id: nil,
        #     data: { id: 1, controller: "dropdown", target: nil },
        #     aria: { label: "Close", hidden: nil }
        #   )
        #   attrs.to_attributes
        #   # => {
        #   #   "class" => "btn btn-primary",
        #   #   "disabled" => "disabled",
        #   #   "data-id" => "1",
        #   #   "data-controller" => "dropdown",
        #   #   "aria-label" => "Close"
        #   # }
        def to_attributes
          each_with_object({}) do |(key, value), hash|
            next if value.nil?

            if key == "data" && value.is_a?(Hash)
              data_attribute(hash, value)
            elsif key == "aria" && value.is_a?(Hash)
              aria_attribute(hash, value)
            elsif BOOLEAN_ATTRIBUTES.include?(key)
              hash[key] = key if value
            else
              hash[key] = format_attribute_value(value)
            end
          end
        end

        private

        # Returns the configuration object for mergers and other settings.
        #
        # @return [Poetry::Core::Config] A deep duplicate of the current configuration
        # @api private
        def config
          @config ||= Poetry::Core::Config.current.deep_dup
        end

        # Normalizes flat data-* and aria-* attributes to nested format.
        #
        # Converts "data-controller" => "dropdown" to data: { controller: "dropdown" }
        # Converts "aria-label" => "Close" to aria: { label: "Close" }
        #
        # @return [void]
        # @api private
        def normalize_flat_attributes!
          flat_data = {}
          flat_aria = {}

          # Find all flat data-* and aria-* attributes
          keys_to_delete = []
          each do |key, value|
            if key.to_s.start_with?("data-")
              nested_key = key.to_s.delete_prefix("data-").underscore
              flat_data[nested_key] = value
              keys_to_delete << key
            elsif key.to_s.start_with?("aria-")
              nested_key = key.to_s.delete_prefix("aria-").underscore
              flat_aria[nested_key] = value
              keys_to_delete << key
            end
          end

          # Remove flat attributes
          keys_to_delete.each { |key| delete(key) }

          # Merge into nested format
          if flat_data.any?
            self["data"] ||= {}
            self["data"].merge!(flat_data)
          end

          return unless flat_aria.any?

          self["aria"] ||= {}
          self["aria"].merge!(flat_aria)
        end

        # Merges data attributes only if they're not already set.
        #
        # @param data_hash [Hash] Hash of data attributes to merge
        # @return [void]
        # @api private
        def merge_data_if_not_set!(data_hash)
          self["data"] ||= {}

          data_hash.each do |key, value|
            set_if_not_present!("data", key, value)
          end
        end

        # Merges aria attributes only if they're not already set.
        #
        # @param aria_hash [Hash] Hash of aria attributes to merge
        # @return [void]
        # @api private
        def merge_aria_if_not_set!(aria_hash)
          self["aria"] ||= {}

          aria_hash.each do |key, value|
            set_if_not_present!("aria", key, value)
          end
        end

        # Sets a nested attribute only if it's not already present in either format.
        #
        # Checks both nested format (e.g., data: { controller: "..." }) and
        # flat format (e.g., "data-controller" => "...").
        #
        # @param prefix [String] The prefix (e.g., "data", "aria")
        # @param key [String, Symbol] The nested key
        # @param value [Object] The value to set
        # @return [void]
        # @api private
        def set_if_not_present!(prefix, key, value)
          return if has_attribute?(prefix, key)

          # Set in nested format
          self[prefix] ||= {}
          self[prefix][key] = value
        end

        # Flattens a nested data hash into prefixed HTML data attributes.
        #
        # @param attributes [Hash] The target hash to populate with flattened attributes
        # @param data [Hash] The nested data hash to flatten
        # @return [void]
        # @api private
        #
        # @example
        #   attributes = {}
        #   data_attribute(attributes, { id: 1, user_name: "John" })
        #   attributes # => { "data-id" => "1", "data-user-name" => "John" }
        def data_attribute(attributes, data)
          data.each_pair do |key, value|
            next if value.nil?

            attributes[prefixed_attribute(:data, key)] = format_attribute_value(value)
          end
        end

        # Flattens a nested aria hash into prefixed HTML aria attributes.
        #
        # Handles special cases for Hash and Array values by flattening them
        # into space-separated strings.
        #
        # @param attributes [Hash] The target hash to populate with flattened attributes
        # @param aria [Hash] The nested aria hash to flatten
        # @return [void]
        # @api private
        #
        # @example
        #   attributes = {}
        #   aria_attribute(attributes, { label: "Close", hidden: true })
        #   attributes # => { "aria-label" => "Close", "aria-hidden" => "true" }
        def aria_attribute(attributes, aria)
          aria.each_pair do |key, value|
            next if value.nil?

            if value.is_a?(Hash) || value.is_a?(Array)
              values = flatten_attribute_values(value)
              next if values.empty?

              value = values.join(" ")
            end

            attributes[prefixed_attribute(:aria, key)] = format_attribute_value(value)
          end
        end

        # Creates a prefixed and dasherized attribute name.
        #
        # @param prefix [Symbol, String] The prefix (e.g., :data, :aria)
        # @param key [Symbol, String] The attribute key
        # @return [String] The prefixed and dasherized attribute name
        # @api private
        #
        # @example
        #   prefixed_attribute(:data, :user_name) # => "data-user-name"
        #   prefixed_attribute(:aria, :labelledby) # => "aria-labelledby"
        def prefixed_attribute(prefix, key)
          "#{prefix}-#{key.to_s.dasherize}"
        end

        # Formats an attribute value for HTML output.
        #
        # Simple types (String, Symbol, BigDecimal) are converted to strings.
        # Complex types are converted to JSON.
        #
        # @param value [Object] The value to format
        # @return [String] The formatted value
        # @api private
        #
        # @example
        #   format_attribute_value("hello") # => "hello"
        #   format_attribute_value(123) # => "123"
        #   format_attribute_value({ a: 1 }) # => '{"a":1}'
        def format_attribute_value(value)
          value.is_a?(String) || value.is_a?(Symbol) || value.is_a?(BigDecimal) ? value.to_s : value.to_json
        end

        # Recursively flattens attribute values from hashes and arrays.
        #
        # - Hash values: includes keys where values are truthy
        # - Array values: recursively flattens nested arrays
        # - Other values: includes if present
        #
        # @param args [Array] Values to flatten
        # @return [Array<String>] Flattened array of string values
        # @api private
        #
        # @example
        #   flatten_attribute_values({ active: true, hidden: false }, "visible")
        #   # => ["active", "visible"]
        def flatten_attribute_values(*args)
          args.each_with_object([]) do |value, tags|
            case value
            when Hash
              value.each { |k, v| tags << k.to_s if v }
            when Array
              tags.concat flatten_attribute_values(*value)
            else
              tags << value.to_s if value.present?
            end
          end
        end

        # Overrides HashWithIndifferentAccess merge behavior for special attributes.
        #
        # Provides custom merge logic for "class" and "data" attributes.
        #
        # @param other_hash [Hash] The hash to merge
        # @param block [Proc] Optional block for custom merge logic
        # @return [Poetry::Core::HTML::Attributes] The merged result
        # @api private
        def update_with_single_argument(other_hash, block)
          update_block = ->(key, old_value, new_value) { update_single_attribute(key, old_value, new_value, &block) }
          super(other_hash, update_block)
        end

        # Handles merging of a single attribute with special logic for certain keys.
        #
        # - "class": Uses classname merger for intelligent class merging
        # - "data": Uses stimulus merger for Stimulus attribute merging
        # - Other keys: Uses provided block or defaults to new value
        #
        # @param key [String] The attribute key
        # @param old_value [Object] The existing value
        # @param new_value [Object] The new value to merge
        # @yield [key, old_value, new_value] Optional block for custom merge logic
        # @return [Object] The merged value
        # @api private
        def update_single_attribute(key, old_value, new_value, &block)
          if key == "class"
            config.classname_merger.merge(old_value, new_value)
          elsif key == "data"
            config.stimulus_merger.merge(old_value, convert_value(new_value), &block)
          elsif block
            yield(key, old_value, new_value)
          else
            new_value
          end
        end
      end
    end
  end
end
