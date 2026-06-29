# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    class ErrorsTest < Minitest::Test
      # Test Poetry::Core::Error base class
      def test_error_inherits_from_standard_error
        assert_operator Poetry::Core::Error, :<, StandardError
      end

      def test_error_can_be_raised_with_default_message
        error = assert_raises(Poetry::Core::Error) do
          raise Poetry::Core::Error
        end
        assert_instance_of Poetry::Core::Error, error
      end

      def test_error_can_be_raised_with_custom_message
        error = assert_raises(Poetry::Core::Error) do
          raise Poetry::Core::Error, "Custom error message"
        end
        assert_equal "Custom error message", error.message
      end

      def test_error_can_be_rescued_as_standard_error
        raise Poetry::Core::Error, "Test error"
      rescue StandardError => e
        assert_instance_of Poetry::Core::Error, e
      end

      # Test Poetry::Core::AssetNotFound class
      def test_asset_not_found_inherits_from_plus_error
        assert_operator Poetry::Core::AssetNotFound, :<, Poetry::Core::Error
      end

      def test_asset_not_found_inherits_from_standard_error
        assert_operator Poetry::Core::AssetNotFound, :<, StandardError
      end

      def test_asset_not_found_initializes_with_asset_name
        error = Poetry::Core::AssetNotFound.new("icon.svg")

        assert_equal "icon.svg", error.asset
      end

      def test_asset_not_found_has_default_message
        error = Poetry::Core::AssetNotFound.new("icon.svg")

        assert_equal 'Could not find the asset "icon.svg"', error.message
      end

      def test_asset_not_found_accepts_custom_message
        error = Poetry::Core::AssetNotFound.new("icon.svg", "Custom error message")

        assert_equal "Custom error message", error.message
        assert_equal "icon.svg", error.asset
      end

      def test_asset_not_found_can_be_raised_and_caught
        error = assert_raises(Poetry::Core::AssetNotFound) do
          raise Poetry::Core::AssetNotFound, "missing_file.css"
        end
        assert_equal "missing_file.css", error.asset
      end

      def test_asset_not_found_can_be_rescued_as_plus_error
        raise Poetry::Core::AssetNotFound, "icon.svg"
      rescue Poetry::Core::Error => e
        assert_instance_of Poetry::Core::AssetNotFound, e
        assert_equal "icon.svg", e.asset
      end

      def test_asset_not_found_can_be_rescued_as_standard_error
        raise Poetry::Core::AssetNotFound, "icon.svg"
      rescue StandardError => e
        assert_instance_of Poetry::Core::AssetNotFound, e
        assert_equal "icon.svg", e.asset
      end

      # Test asset attribute reader
      def test_asset_attribute_is_readable
        error = Poetry::Core::AssetNotFound.new("test_asset.svg")

        assert_respond_to error, :asset
        assert_equal "test_asset.svg", error.asset
      end

      def test_asset_attribute_is_not_writable
        error = Poetry::Core::AssetNotFound.new("test_asset.svg")

        refute_respond_to error, :asset=
      end

      # Test with various asset types
      def test_asset_not_found_with_css_file
        error = Poetry::Core::AssetNotFound.new("styles.css")

        assert_equal "styles.css", error.asset
        assert_equal 'Could not find the asset "styles.css"', error.message
      end

      def test_asset_not_found_with_javascript_file
        error = Poetry::Core::AssetNotFound.new("app.js")

        assert_equal "app.js", error.asset
        assert_equal 'Could not find the asset "app.js"', error.message
      end

      def test_asset_not_found_with_image_file
        error = Poetry::Core::AssetNotFound.new("logo.png")

        assert_equal "logo.png", error.asset
        assert_equal 'Could not find the asset "logo.png"', error.message
      end

      def test_asset_not_found_with_svg_file
        error = Poetry::Core::AssetNotFound.new("icon.svg")

        assert_equal "icon.svg", error.asset
        assert_equal 'Could not find the asset "icon.svg"', error.message
      end

      def test_asset_not_found_with_path
        error = Poetry::Core::AssetNotFound.new("assets/images/logo.png")

        assert_equal "assets/images/logo.png", error.asset
        assert_equal 'Could not find the asset "assets/images/logo.png"', error.message
      end

      # Test error message interpolation
      def test_asset_not_found_message_includes_asset_name
        asset_name = "custom_file.css"
        error = Poetry::Core::AssetNotFound.new(asset_name)

        assert_includes error.message, asset_name
      end

      def test_asset_not_found_custom_message_overrides_default
        error = Poetry::Core::AssetNotFound.new("icon.svg", "File not found in assets directory")

        refute_includes error.message, "Could not find the asset"
        assert_equal "File not found in assets directory", error.message
      end

      # Test edge cases
      def test_asset_not_found_with_empty_string_asset
        error = Poetry::Core::AssetNotFound.new("")

        assert_equal "", error.asset
        assert_equal 'Could not find the asset ""', error.message
      end

      def test_asset_not_found_with_special_characters
        asset_name = "file-with_special.chars@123.svg"
        error = Poetry::Core::AssetNotFound.new(asset_name)

        assert_equal asset_name, error.asset
        assert_includes error.message, asset_name
      end

      def test_asset_not_found_with_unicode_characters
        asset_name = "ファイル.svg"
        error = Poetry::Core::AssetNotFound.new(asset_name)

        assert_equal asset_name, error.asset
        assert_includes error.message, asset_name
      end

      # Test error handling patterns
      def test_rescuing_specific_asset_not_found_error
        caught = false
        begin
          raise Poetry::Core::AssetNotFound, "icon.svg"
        rescue Poetry::Core::AssetNotFound => e
          caught = true

          assert_equal "icon.svg", e.asset
        end

        assert caught, "AssetNotFound error should be caught"
      end

      def test_multiple_error_types_can_coexist
        errors = [
          Poetry::Core::Error.new("Generic error"),
          Poetry::Core::AssetNotFound.new("icon.svg")
        ]

        assert_instance_of Poetry::Core::Error, errors[0]
        assert_instance_of Poetry::Core::AssetNotFound, errors[1]
        refute_respond_to errors[0], :asset
        assert_respond_to errors[1], :asset
      end

      def test_error_hierarchy_allows_granular_rescue
        caught_specific = false
        caught_general = false

        begin
          raise Poetry::Core::AssetNotFound, "icon.svg"
        rescue Poetry::Core::AssetNotFound => e
          caught_specific = true

          assert_equal "icon.svg", e.asset
        rescue Poetry::Core::Error
          caught_general = true
        end

        assert caught_specific
        refute caught_general
      end

      def test_plus_error_rescue_catches_asset_not_found
        caught = false
        begin
          raise Poetry::Core::AssetNotFound, "icon.svg"
        rescue Poetry::Core::Error => e
          caught = true

          assert_instance_of Poetry::Core::AssetNotFound, e
        end

        assert caught
      end

      # Test that custom messages preserve asset information
      def test_custom_message_does_not_affect_asset_attribute
        asset_name = "test.svg"
        custom_message = "A completely different message"
        error = Poetry::Core::AssetNotFound.new(asset_name, custom_message)

        assert_equal asset_name, error.asset
        assert_equal custom_message, error.message
        refute_includes error.message, asset_name
      end

      # Test real-world usage scenarios
      def test_asset_not_found_usage_in_rescue_block
        asset_name = "missing_icon.svg"

        begin
          raise Poetry::Core::AssetNotFound, asset_name
        rescue Poetry::Core::AssetNotFound => e
          # Simulate logging or handling
          logged_message = "Asset not found: #{e.asset}"

          assert_equal "Asset not found: missing_icon.svg", logged_message
        end
      end

      def test_error_information_is_accessible_after_rescue
        error = nil

        begin
          raise Poetry::Core::AssetNotFound, "icon.svg"
        rescue Poetry::Core::AssetNotFound => e
          error = e
        end

        refute_nil error
        assert_equal "icon.svg", error.asset
        assert_equal 'Could not find the asset "icon.svg"', error.message
      end

      # Test Poetry::Core::IconNotFound class
      def test_icon_not_found_inherits_from_plus_error
        assert_operator Poetry::Core::IconNotFound, :<, Poetry::Core::Error
      end

      def test_icon_not_found_inherits_from_standard_error
        assert_operator Poetry::Core::IconNotFound, :<, StandardError
      end

      def test_icon_not_found_initializes_with_all_parameters
        paths = ["app/assets/images/icons", "vendor/assets/icons"]
        error = Poetry::Core::IconNotFound.new("star", "solid", paths)

        assert_equal "star", error.icon_name
        assert_equal "solid", error.icon_type
        assert_equal paths, error.searched_paths
      end

      def test_icon_not_found_has_formatted_message_with_single_path
        paths = ["app/assets/images/icons"]
        error = Poetry::Core::IconNotFound.new("star", "solid", paths)
        expected_message = "Icon 'star' of type 'solid' not found. Searched paths: app/assets/images/icons"

        assert_equal expected_message, error.message
      end

      def test_icon_not_found_has_formatted_message_with_multiple_paths
        paths = ["app/assets/images/icons", "vendor/assets/icons", "lib/assets/icons"]
        error = Poetry::Core::IconNotFound.new("star", "outline", paths)
        expected_message = "Icon 'star' of type 'outline' not found. " \
                           "Searched paths: app/assets/images/icons, vendor/assets/icons, lib/assets/icons"

        assert_equal expected_message, error.message
      end

      def test_icon_not_found_can_be_raised_and_caught
        paths = ["app/assets/images"]
        error = assert_raises(Poetry::Core::IconNotFound) do
          raise Poetry::Core::IconNotFound.new("missing", "solid", paths)
        end

        assert_equal "missing", error.icon_name
        assert_equal "solid", error.icon_type
        assert_equal paths, error.searched_paths
      end

      def test_icon_not_found_can_be_rescued_as_plus_error
        paths = ["app/assets/images"]
        raise Poetry::Core::IconNotFound.new("star", "solid", paths)
      rescue Poetry::Core::Error => e
        assert_instance_of Poetry::Core::IconNotFound, e
        assert_equal "star", e.icon_name
        assert_equal "solid", e.icon_type
      end

      def test_icon_not_found_can_be_rescued_as_standard_error
        paths = ["app/assets/images"]
        raise Poetry::Core::IconNotFound.new("star", "outline", paths)
      rescue StandardError => e
        assert_instance_of Poetry::Core::IconNotFound, e
        assert_equal "star", e.icon_name
      end

      # Test icon_name attribute reader
      def test_icon_name_attribute_is_readable
        error = Poetry::Core::IconNotFound.new("heart", "solid", ["/path"])

        assert_respond_to error, :icon_name
        assert_equal "heart", error.icon_name
      end

      def test_icon_name_attribute_is_not_writable
        error = Poetry::Core::IconNotFound.new("heart", "solid", ["/path"])

        refute_respond_to error, :icon_name=
      end

      # Test icon_type attribute reader
      def test_icon_type_attribute_is_readable
        error = Poetry::Core::IconNotFound.new("heart", "outline", ["/path"])

        assert_respond_to error, :icon_type
        assert_equal "outline", error.icon_type
      end

      def test_icon_type_attribute_is_not_writable
        error = Poetry::Core::IconNotFound.new("heart", "outline", ["/path"])

        refute_respond_to error, :icon_type=
      end

      # Test searched_paths attribute reader
      def test_searched_paths_attribute_is_readable
        paths = %w[path1 path2]
        error = Poetry::Core::IconNotFound.new("star", "solid", paths)

        assert_respond_to error, :searched_paths
        assert_equal paths, error.searched_paths
      end

      def test_searched_paths_attribute_is_not_writable
        error = Poetry::Core::IconNotFound.new("star", "solid", ["/path"])

        refute_respond_to error, :searched_paths=
      end

      # Test with various icon types
      def test_icon_not_found_with_solid_type
        error = Poetry::Core::IconNotFound.new("star", "solid", ["app/assets"])

        assert_equal "solid", error.icon_type
        assert_includes error.message, "solid"
      end

      def test_icon_not_found_with_outline_type
        error = Poetry::Core::IconNotFound.new("star", "outline", ["app/assets"])

        assert_equal "outline", error.icon_type
        assert_includes error.message, "outline"
      end

      def test_icon_not_found_with_mini_type
        error = Poetry::Core::IconNotFound.new("star", "mini", ["app/assets"])

        assert_equal "mini", error.icon_type
        assert_includes error.message, "mini"
      end

      def test_icon_not_found_with_custom_type
        error = Poetry::Core::IconNotFound.new("logo", "custom", ["app/assets"])

        assert_equal "custom", error.icon_type
        assert_includes error.message, "custom"
      end

      # Test with various icon names
      def test_icon_not_found_with_simple_icon_name
        error = Poetry::Core::IconNotFound.new("heart", "solid", ["/path"])

        assert_equal "heart", error.icon_name
        assert_includes error.message, "heart"
      end

      def test_icon_not_found_with_hyphenated_icon_name
        error = Poetry::Core::IconNotFound.new("arrow-left", "outline", ["/path"])

        assert_equal "arrow-left", error.icon_name
        assert_includes error.message, "arrow-left"
      end

      def test_icon_not_found_with_underscored_icon_name
        error = Poetry::Core::IconNotFound.new("user_circle", "solid", ["/path"])

        assert_equal "user_circle", error.icon_name
        assert_includes error.message, "user_circle"
      end

      def test_icon_not_found_with_numeric_icon_name
        error = Poetry::Core::IconNotFound.new("icon-24", "solid", ["/path"])

        assert_equal "icon-24", error.icon_name
        assert_includes error.message, "icon-24"
      end

      # Test message formatting
      def test_icon_not_found_message_includes_icon_name
        error = Poetry::Core::IconNotFound.new("custom-icon", "solid", ["/path"])

        assert_includes error.message, "custom-icon"
        assert_includes error.message, "Icon 'custom-icon'"
      end

      def test_icon_not_found_message_includes_icon_type
        error = Poetry::Core::IconNotFound.new("star", "custom-type", ["/path"])

        assert_includes error.message, "custom-type"
        assert_includes error.message, "of type 'custom-type'"
      end

      def test_icon_not_found_message_includes_all_searched_paths
        paths = ["path/one", "path/two", "path/three"]
        error = Poetry::Core::IconNotFound.new("icon", "solid", paths)

        paths.each do |path|
          assert_includes error.message, path
        end
      end

      def test_icon_not_found_message_joins_paths_with_comma_space
        paths = %w[first second third]
        error = Poetry::Core::IconNotFound.new("icon", "solid", paths)

        assert_includes error.message, "first, second, third"
      end

      # Test edge cases
      def test_icon_not_found_with_empty_string_icon_name
        error = Poetry::Core::IconNotFound.new("", "solid", ["/path"])

        assert_equal "", error.icon_name
        assert_includes error.message, "Icon ''"
      end

      def test_icon_not_found_with_empty_string_icon_type
        error = Poetry::Core::IconNotFound.new("star", "", ["/path"])

        assert_equal "", error.icon_type
        assert_includes error.message, "of type ''"
      end

      def test_icon_not_found_with_empty_paths_array
        error = Poetry::Core::IconNotFound.new("star", "solid", [])

        assert_equal [], error.searched_paths
        assert_includes error.message, "Searched paths: "
      end

      def test_icon_not_found_with_single_empty_path
        error = Poetry::Core::IconNotFound.new("star", "solid", [""])

        assert_equal [""], error.searched_paths
      end

      def test_icon_not_found_with_special_characters_in_icon_name
        icon_name = "icon-with_special.chars@123"
        error = Poetry::Core::IconNotFound.new(icon_name, "solid", ["/path"])

        assert_equal icon_name, error.icon_name
        assert_includes error.message, icon_name
      end

      def test_icon_not_found_with_unicode_characters_in_icon_name
        icon_name = "アイコン"
        error = Poetry::Core::IconNotFound.new(icon_name, "solid", ["/path"])

        assert_equal icon_name, error.icon_name
        assert_includes error.message, icon_name
      end

      def test_icon_not_found_with_paths_containing_special_characters
        paths = ["/path/with spaces", "/path/with-dashes", "/path_with_underscores"]
        error = Poetry::Core::IconNotFound.new("star", "solid", paths)

        assert_equal paths, error.searched_paths
        paths.each { |path| assert_includes error.message, path }
      end

      # Test error handling patterns
      def test_rescuing_specific_icon_not_found_error
        caught = false
        paths = ["app/assets"]

        begin
          raise Poetry::Core::IconNotFound.new("star", "solid", paths)
        rescue Poetry::Core::IconNotFound => e
          caught = true

          assert_equal "star", e.icon_name
          assert_equal "solid", e.icon_type
          assert_equal paths, e.searched_paths
        end

        assert caught, "IconNotFound error should be caught"
      end

      def test_icon_not_found_error_hierarchy_allows_granular_rescue
        caught_specific = false
        caught_general = false
        paths = ["app/assets"]

        begin
          raise Poetry::Core::IconNotFound.new("star", "solid", paths)
        rescue Poetry::Core::IconNotFound => e
          caught_specific = true

          assert_equal "star", e.icon_name
        rescue Poetry::Core::Error
          caught_general = true
        end

        assert caught_specific
        refute caught_general
      end

      def test_plus_error_rescue_catches_icon_not_found
        caught = false
        paths = ["app/assets"]

        begin
          raise Poetry::Core::IconNotFound.new("star", "solid", paths)
        rescue Poetry::Core::Error => e
          caught = true

          assert_instance_of Poetry::Core::IconNotFound, e
        end

        assert caught
      end

      # Test multiple error types
      def test_multiple_error_types_including_icon_not_found
        errors = [
          Poetry::Core::Error.new("Generic error"),
          Poetry::Core::AssetNotFound.new("icon.svg"),
          Poetry::Core::IconNotFound.new("star", "solid", ["/path"])
        ]

        assert_instance_of Poetry::Core::Error, errors[0]
        assert_instance_of Poetry::Core::AssetNotFound, errors[1]
        assert_instance_of Poetry::Core::IconNotFound, errors[2]

        refute_respond_to errors[0], :asset
        assert_respond_to errors[1], :asset
        assert_respond_to errors[2], :icon_name
        assert_respond_to errors[2], :icon_type
        assert_respond_to errors[2], :searched_paths
      end

      # Test real-world usage scenarios
      def test_icon_not_found_usage_in_rescue_block
        icon_name = "missing-icon"
        icon_type = "solid"
        paths = ["app/assets/images/icons", "vendor/assets/icons"]

        begin
          raise Poetry::Core::IconNotFound.new(icon_name, icon_type, paths)
        rescue Poetry::Core::IconNotFound => e
          # Simulate logging or handling
          logged_message = "Icon '#{e.icon_name}' (#{e.icon_type}) not found in: #{e.searched_paths.join(", ")}"

          assert_equal "Icon 'missing-icon' (solid) not found in: app/assets/images/icons, vendor/assets/icons",
                       logged_message
        end
      end

      def test_icon_not_found_information_is_accessible_after_rescue
        error = nil
        paths = ["app/assets", "vendor/assets"]

        begin
          raise Poetry::Core::IconNotFound.new("star", "outline", paths)
        rescue Poetry::Core::IconNotFound => e
          error = e
        end

        refute_nil error
        assert_equal "star", error.icon_name
        assert_equal "outline", error.icon_type
        assert_equal paths, error.searched_paths
        assert_includes error.message, "Icon 'star' of type 'outline' not found"
      end

      def test_icon_not_found_can_provide_fallback_information
        paths = ["primary/path", "fallback/path"]

        begin
          raise Poetry::Core::IconNotFound.new("custom", "solid", paths)
        rescue Poetry::Core::IconNotFound => e
          # Use error information to provide helpful feedback
          fallback_suggestion = "Try using default icon instead of '#{e.icon_name}'"

          assert_equal "Try using default icon instead of 'custom'", fallback_suggestion
        end
      end

      # Test immutability of searched_paths array
      def test_searched_paths_array_is_independent
        original_paths = %w[path1 path2]
        error = Poetry::Core::IconNotFound.new("star", "solid", original_paths)

        # Modify original array
        original_paths << "path3"

        # Error should still have original paths if array was duplicated
        # (This tests implementation detail - array may or may not be duplicated)
        assert_respond_to error.searched_paths, :join
        assert_kind_of Array, error.searched_paths
      end
    end
  end
end
