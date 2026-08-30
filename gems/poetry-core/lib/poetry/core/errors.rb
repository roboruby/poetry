# frozen_string_literal: true

# Poetry::Core module provides extensions and enhancements for Rails views and components.
module Poetry
  module Core
    # Base error class for all Poetry::Core-related errors.
    #
    # All custom errors in the Poetry::Core module inherit from this class, which in turn
    # inherits from Ruby's StandardError. This provides a common ancestor for
    # rescuing all Poetry::Core-specific exceptions.
    #
    # @example Rescuing all Poetry::Core errors
    #   begin
    #     # Poetry::Core operations
    #   rescue Poetry::Core::Error => e
    #     Rails.logger.error("Poetry::Core error: #{e.message}")
    #   end
    class Error < StandardError; end

    # Raised by an icon set's #fetch for a name it cannot serve -
    # malformed, or simply not in the set. This is the public rescue
    # point of the icon system: the Icon component's missing-icon policy
    # rescues exactly this class, so a custom set registered via
    # {Poetry::Core::Icons.register} must raise it too (that is the set
    # contract).
    #
    # @example Custom handling around a dynamic icon name
    #   begin
    #     Poetry::Core::Icons.set.fetch(user_preference)
    #   rescue Poetry::Core::IconNotFound => e
    #     logger.info("missing icon #{e.name.inspect}") # e.suggestion may name the fix
    #   end
    class IconNotFound < Error
      # @return [Symbol, String] the requested icon name, as given
      attr_reader :name

      # @return [String, nil] the closest valid name, when one exists
      attr_reader :suggestion

      # Carries the requested name (and the did-you-mean fix, when one
      # exists) alongside the message.
      #
      # @param message [String] the full error message
      # @param name [Symbol, String] the requested icon name
      # @param suggestion [String, nil] the closest valid name, when known
      def initialize(message, name:, suggestion: nil)
        super(message)
        @name = name
        @suggestion = suggestion
      end
    end
  end
end
