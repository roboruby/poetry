# frozen_string_literal: true

module Poetry
  module Core
    # Adapted from https://github.com/jefawks3/fox_tail/blob/main/lib/fox_tail/stimulus_merger.rb
    module Stimulus
      # Intelligently merges Stimulus controller data attributes from multiple sources.
      #
      # This class handles the complex task of combining Stimulus data attributes
      # (controllers, actions, targets, values, classes, etc.) without duplicating
      # controllers or actions. This is particularly useful when building components
      # that may have Stimulus attributes from multiple concerns or sources.
      #
      # @example Merging attributes with duplicate controllers
      #   merger = Poetry::Core::Stimulus::Merger.new
      #   attrs1 = { data: { controller: "dropdown modal" } }
      #   attrs2 = { data: { controller: "dropdown tooltip" } }
      #   merged = merger.merge_attributes(attrs1, attrs2)
      #   # => { data: { controller: "dropdown modal tooltip" } }
      #
      # @example Merging with actions
      #   merger = Poetry::Core::Stimulus::Merger.new
      #   attrs1 = { data: { controller: "form", action: "submit->form#save" } }
      #   attrs2 = { data: { action: "keyup->form#validate" } }
      #   merged = merger.merge_attributes(attrs1, attrs2)
      #   # => { data: { controller: "form", action: "submit->form#save keyup->form#validate" } }
      class Merger
        # Merges stimulus attributes in place, modifying the original attributes hash.
        #
        # @param attributes [Hash] The base attributes hash to merge into (will be modified)
        # @param other_attributes [Array<Hash>] One or more attribute hashes to merge
        # @return [Hash] The modified attributes hash
        def merge_attributes!(attributes, *other_attributes)
          attributes[:data] ||= {}
          other_attributes.each { |attr| merge_stimulus_attributes attributes, attr }
          attributes
        end

        # Merges stimulus attributes non-destructively by deep duplicating the original.
        #
        # @param attributes [Hash] The base attributes hash (will not be modified)
        # @param other_attributes [Array<Hash>] One or more attribute hashes to merge
        # @return [Hash] A new hash with merged attributes
        def merge_attributes(attributes, *other_attributes)
          merge_attributes!(attributes.deep_dup, *other_attributes)
        end

        # Merges multiple controller strings into a single deduplicated string.
        #
        # Controller names are split on spaces, deduplicated, and rejoined.
        # Blank or nil values are ignored.
        #
        # @param controllers [Array<String, nil>] One or more controller strings
        # @return [String, nil] Space-separated controller names, or nil if all inputs were blank
        # @example
        #   merge_controllers("dropdown modal", "dropdown tooltip")
        #   # => "dropdown modal tooltip"
        def merge_controllers(*controllers)
          normalize = controllers.flatten.each_with_object({}) do |controller, result|
            next if controller.blank?

            controller.split.each { |identifier| result[identifier] = true }
          end

          normalize.keys.join(" ").presence
        end

        # Merges multiple action strings into a single deduplicated string.
        #
        # Action strings are flattened, filtered for presence, deduplicated, and joined.
        # Unlike controllers, actions maintain their insertion order.
        #
        # @param actions [Array<String, nil>] One or more action strings
        # @return [String, nil] Space-separated action strings, or nil if all inputs were blank
        # @example
        #   merge_actions("click->modal#open", "click->modal#open", "keyup->form#validate")
        #   # => "click->modal#open keyup->form#validate"
        def merge_actions(*actions)
          actions.flatten.compact_blank.uniq.join(" ").presence
        end

        # Merges multiple stimulus data hashes with special handling for controllers and actions.
        #
        # This is the main merging method that intelligently combines stimulus data hashes.
        # Controller and action values are deduplicated using their respective merge methods,
        # while other data attributes are merged normally.
        #
        # @param hashes [Array<Hash>] One or more stimulus data hashes
        # @param block [Proc] Optional block passed to Hash#merge for custom merge logic
        # @return [Hash] A new hash with merged stimulus data
        # @example
        #   merge(
        #     { controller: "dropdown", action: "click->dropdown#toggle" },
        #     { controller: "dropdown tooltip", target_value: "main" }
        #   )
        #   # => { controller: "dropdown tooltip", action: "click->dropdown#toggle", target_value: "main" }
        def merge(*hashes, &block)
          hashes.flatten.compact.each_with_object({}.with_indifferent_access) do |hash, result|
            hash = hash.deep_dup.with_indifferent_access
            result[:controller] = merge_controllers(result[:controller], hash.delete(:controller))
            result[:action] = merge_actions(result[:action], hash.delete(:action))
            result.merge!(hash, &block)
          end
        end

        private

        # Merges stimulus-specific attributes from one hash into another.
        #
        # This private helper method handles the actual merging of stimulus data attributes,
        # extracting and merging controllers and actions separately before performing a deep merge
        # of the remaining attributes.
        #
        # @param source [Hash] The source attributes hash (will be modified)
        # @param attributes [Hash] The attributes to merge into source
        # @return [void]
        def merge_stimulus_attributes(source, attributes)
          attributes[:data] ||= {}
          controllers = merge_controllers source[:data].delete(:controller), attributes[:data].delete(:controller)
          actions = merge_actions source[:data].delete(:action), attributes[:data].delete(:action)
          source[:data][:controller] = controllers
          source[:data][:action] = actions
          source.deep_merge! attributes
        end
      end
    end
  end
end
