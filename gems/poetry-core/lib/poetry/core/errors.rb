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

    # Error raised when an asset cannot be found.
    #
    # This error is typically raised when attempting to load or reference an asset
    # (such as a CSS file, JavaScript file, or image) that does not exist in the
    # expected location.
    #
    # @example Handling missing asset
    #   begin
    #     load_asset('missing_icon.svg')
    #   rescue Poetry::Core::AssetNotFound => e
    #     Rails.logger.warn("Asset not found: #{e.asset}")
    #   end
    class AssetNotFound < Error
      # @return [String] the name or path of the asset that could not be found
      attr_reader :asset

      # Creates a new AssetNotFound error.
      #
      # @param asset [String] the name or path of the asset that could not be found
      # @param msg [String] optional custom error message. Defaults to a formatted
      #   message including the asset name
      #
      # @example With default message
      #   raise Poetry::Core::AssetNotFound.new('icon.svg')
      #
      # @example With custom message
      #   raise Poetry::Core::AssetNotFound.new('icon.svg', 'Custom error message')
      def initialize(asset, msg = "Could not find the asset \"#{asset}\"")
        super(msg)
        @asset = asset
      end
    end

    # Error raised when an icon cannot be found in the expected paths.
    #
    # This error is typically raised when attempting to load an icon (such as an SVG)
    # that does not exist in any of the searched paths. It provides detailed information
    # about what was searched and where, making it easier to debug icon loading issues.
    #
    # @example Handling missing icon
    #   begin
    #     load_icon('star', 'solid')
    #   rescue Poetry::Core::IconNotFound => e
    #     Rails.logger.warn("Icon '#{e.icon_name}' not found in paths: #{e.searched_paths}")
    #   end
    #
    # @example Providing fallback when icon not found
    #   begin
    #     icon_path = find_icon('custom-icon', 'outline')
    #   rescue Poetry::Core::IconNotFound => e
    #     icon_path = default_icon_path
    #   end
    class IconNotFound < Error
      # @return [String] the name of the icon that could not be found
      attr_reader :icon_name

      # @return [String] the type/variant of the icon (e.g., 'solid', 'outline')
      attr_reader :icon_type

      # @return [Array<String>] the paths that were searched for the icon
      attr_reader :searched_paths

      # Creates a new IconNotFound error.
      #
      # @param icon_name [String] the name of the icon that could not be found
      # @param icon_type [String] the type/variant of the icon (e.g., 'solid', 'outline')
      # @param searched_paths [Array<String>] the paths that were searched for the icon
      #
      # @example With single search path
      #   raise Poetry::Core::IconNotFound.new('star', 'solid', ['app/assets/images/icons'])
      #
      # @example With multiple search paths
      #   raise Poetry::Core::IconNotFound.new('star', 'outline', [
      #     'app/assets/images/icons',
      #     'vendor/assets/images/icons',
      #     'lib/assets/images/icons'
      #   ])
      def initialize(icon_name, icon_type, searched_paths)
        @icon_name = icon_name
        @icon_type = icon_type
        @searched_paths = searched_paths
        super(build_message)
      end

      private

      def build_message
        "Icon '#{icon_name}' of type '#{icon_type}' not found. Searched paths: #{searched_paths.join(", ")}"
      end
    end
  end
end
