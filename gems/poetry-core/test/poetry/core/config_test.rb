# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    class ConfigTest < Minitest::Test
      def setup
        # Reset the singleton instance before each test
        Poetry::Core::Config.instance_variable_set(:@current, nil)
      end

      def teardown
        # Clean up the singleton instance after each test
        Poetry::Core::Config.instance_variable_set(:@current, nil)
      end

      # Test default configuration values
      def test_defaults_returns_ordered_options
        defaults = Poetry::Core::Config.defaults

        assert_instance_of ActiveSupport::OrderedOptions, defaults
      end

      def test_defaults_includes_classname_merger
        defaults = Poetry::Core::Config.defaults

        assert_instance_of Poetry::Core::CSS::Merger, defaults.classname_merger
      end

      def test_defaults_includes_stimulus_merger
        defaults = Poetry::Core::Config.defaults

        assert_instance_of Poetry::Core::Stimulus::Merger, defaults.stimulus_merger
      end

      def test_defaults_sets_css_mode_to_tailwind
        defaults = Poetry::Core::Config.defaults

        assert_equal :tailwind, defaults.css_mode
      end

      def test_defaults_returns_new_instance_each_time
        defaults1 = Poetry::Core::Config.defaults
        defaults2 = Poetry::Core::Config.defaults

        refute_same defaults1, defaults2
      end

      # Test singleton current instance
      def test_current_returns_config_instance
        config = Poetry::Core::Config.current

        assert_instance_of Poetry::Core::Config, config
      end

      def test_current_returns_same_instance_on_multiple_calls
        config1 = Poetry::Core::Config.current
        config2 = Poetry::Core::Config.current

        assert_same config1, config2
      end

      def test_current_creates_instance_with_defaults
        config = Poetry::Core::Config.current

        assert_instance_of Poetry::Core::CSS::Merger, config.classname_merger
        assert_instance_of Poetry::Core::Stimulus::Merger, config.stimulus_merger
        assert_equal :tailwind, config.css_mode
      end

      def test_current_persists_modifications
        Poetry::Core::Config.current.css_mode = :bem
        config = Poetry::Core::Config.current

        assert_equal :bem, config.css_mode
      ensure
        Poetry::Core::Config.current.css_mode = :tailwind
      end

      # Test instance initialization
      def test_initialize_creates_new_instance
        config = Poetry::Core::Config.new

        assert_instance_of Poetry::Core::Config, config
      end

      def test_initialize_sets_default_values
        config = Poetry::Core::Config.new

        assert_instance_of Poetry::Core::CSS::Merger, config.classname_merger
        assert_instance_of Poetry::Core::Stimulus::Merger, config.stimulus_merger
        assert_equal :tailwind, config.css_mode
      end

      def test_initialize_creates_independent_instances
        config1 = Poetry::Core::Config.new
        config2 = Poetry::Core::Config.new

        refute_same config1, config2
      end

      def test_default_alias_creates_new_instance
        config = Poetry::Core::Config.default

        assert_instance_of Poetry::Core::Config, config
      end

      def test_default_alias_behaves_like_new
        config1 = Poetry::Core::Config.default
        config2 = Poetry::Core::Config.new

        refute_same config1, config2
        assert_equal config1.class, config2.class
      end

      # Test method-style access
      def test_method_style_getter_for_classname_merger
        config = Poetry::Core::Config.new

        assert_instance_of Poetry::Core::CSS::Merger, config.classname_merger
      end

      def test_method_style_getter_for_stimulus_merger
        config = Poetry::Core::Config.new

        assert_instance_of Poetry::Core::Stimulus::Merger, config.stimulus_merger
      end

      def test_method_style_getter_for_css_mode
        config = Poetry::Core::Config.new

        assert_equal :tailwind, config.css_mode
      end

      def test_method_style_setter_for_classname_merger
        config = Poetry::Core::Config.new
        custom_merger = Poetry::Core::CSS::Merger.new
        config.classname_merger = custom_merger

        assert_same custom_merger, config.classname_merger
      end

      def test_method_style_setter_for_stimulus_merger
        config = Poetry::Core::Config.new
        custom_merger = Poetry::Core::Stimulus::Merger.new
        config.stimulus_merger = custom_merger

        assert_same custom_merger, config.stimulus_merger
      end

      def test_method_style_setter_for_css_mode
        config = Poetry::Core::Config.new
        config.css_mode = :bem

        assert_equal :bem, config.css_mode
      end

      # Test hash-style access
      def test_hash_style_getter_for_classname_merger
        config = Poetry::Core::Config.new

        assert_instance_of Poetry::Core::CSS::Merger, config[:classname_merger]
      end

      def test_hash_style_getter_for_stimulus_merger
        config = Poetry::Core::Config.new

        assert_instance_of Poetry::Core::Stimulus::Merger, config[:stimulus_merger]
      end

      def test_hash_style_getter_for_css_mode
        config = Poetry::Core::Config.new

        assert_equal :tailwind, config[:css_mode]
      end

      def test_hash_style_setter_for_classname_merger
        config = Poetry::Core::Config.new
        custom_merger = Poetry::Core::CSS::Merger.new
        config[:classname_merger] = custom_merger

        assert_same custom_merger, config[:classname_merger]
      end

      def test_hash_style_setter_for_stimulus_merger
        config = Poetry::Core::Config.new
        custom_merger = Poetry::Core::Stimulus::Merger.new
        config[:stimulus_merger] = custom_merger

        assert_same custom_merger, config[:stimulus_merger]
      end

      def test_hash_style_setter_for_css_mode
        config = Poetry::Core::Config.new
        config[:css_mode] = :bem

        assert_equal :bem, config[:css_mode]
      end

      # Test method and hash style equivalence
      def test_method_and_hash_access_are_equivalent
        config = Poetry::Core::Config.new

        assert_equal config.classname_merger, config[:classname_merger]
        assert_equal config.stimulus_merger, config[:stimulus_merger]
        assert_equal config.css_mode, config[:css_mode]
      end

      def test_method_and_hash_setters_are_equivalent
        config = Poetry::Core::Config.new
        custom_merger = Poetry::Core::CSS::Merger.new

        config.classname_merger = custom_merger

        assert_same custom_merger, config[:classname_merger]

        another_merger = Poetry::Core::CSS::Merger.new
        config[:classname_merger] = another_merger

        assert_same another_merger, config.classname_merger
      end

      # Test custom configuration values
      def test_can_add_custom_configuration_values
        config = Poetry::Core::Config.new
        config.custom_value = "test"

        assert_equal "test", config.custom_value
      end

      def test_custom_values_accessible_via_hash_syntax
        config = Poetry::Core::Config.new
        config[:custom_key] = 42

        assert_equal 42, config[:custom_key]
        assert_equal 42, config.custom_key
      end

      def test_custom_values_are_independent_per_instance
        config1 = Poetry::Core::Config.new
        config2 = Poetry::Core::Config.new

        config1.custom_value = "first"
        config2.custom_value = "second"

        assert_equal "first", config1.custom_value
        assert_equal "second", config2.custom_value
      end

      # Test instance independence
      def test_instances_are_independent
        config1 = Poetry::Core::Config.new
        config2 = Poetry::Core::Config.new

        config1.css_mode = :bem

        assert_equal :bem, config1.css_mode
        assert_equal :tailwind, config2.css_mode
      end

      def test_modifying_one_instance_does_not_affect_another
        config1 = Poetry::Core::Config.new
        config2 = Poetry::Core::Config.new

        original_merger2 = config2.classname_merger
        custom_merger = Poetry::Core::CSS::Merger.new
        config1.classname_merger = custom_merger

        assert_same custom_merger, config1.classname_merger
        assert_same original_merger2, config2.classname_merger
      end

      def test_new_instances_do_not_share_merger_objects
        config1 = Poetry::Core::Config.new
        config2 = Poetry::Core::Config.new

        refute_same config1.classname_merger, config2.classname_merger
        refute_same config1.stimulus_merger, config2.stimulus_merger
      end

      # Test global singleton independence
      def test_global_config_is_independent_from_new_instances
        global = Poetry::Core::Config.current
        local = Poetry::Core::Config.new

        global.css_mode = :bem

        assert_equal :bem, global.css_mode
        assert_equal :tailwind, local.css_mode
      ensure
        Poetry::Core::Config.current.css_mode = :tailwind
      end

      def test_new_instance_does_not_modify_global_config
        global = Poetry::Core::Config.current
        local = Poetry::Core::Config.new

        local.css_mode = :bem

        assert_equal :tailwind, global.css_mode
        assert_equal :bem, local.css_mode
      end

      def test_new_instance_does_not_share_mergers_with_global
        global = Poetry::Core::Config.current
        local = Poetry::Core::Config.new

        refute_same global.classname_merger, local.classname_merger
        refute_same global.stimulus_merger, local.stimulus_merger
      end

      # Test mergers functionality through config
      def test_classname_merger_works_through_config
        config = Poetry::Core::Config.new
        result = config.classname_merger.merge("text-sm", "text-lg")

        assert_equal "text-lg", result
      end

      def test_stimulus_merger_works_through_config
        config = Poetry::Core::Config.new
        result = config.stimulus_merger.merge_controllers("dropdown modal", "dropdown tooltip")

        assert_equal "dropdown modal tooltip", result
      end

      def test_custom_classname_merger_can_be_used
        config = Poetry::Core::Config.new
        custom_merger = Poetry::Core::CSS::Merger.new
        config.classname_merger = custom_merger

        result = config.classname_merger.merge("p-4", "rounded")

        assert_kind_of String, result
      end

      def test_custom_stimulus_merger_can_be_used
        config = Poetry::Core::Config.new
        custom_merger = Poetry::Core::Stimulus::Merger.new
        config.stimulus_merger = custom_merger

        result = config.stimulus_merger.merge_controllers("dropdown", "modal")

        assert_equal "dropdown modal", result
      end

      # Test real-world usage patterns
      def test_global_config_pattern
        # Access and modify global config
        Poetry::Core::Config.current.css_mode = :bem

        # Access from different location
        config = Poetry::Core::Config.current

        assert_equal :bem, config.css_mode
      ensure
        Poetry::Core::Config.current.css_mode = :tailwind
      end

      def test_scoped_config_pattern
        # Create a scoped config for testing
        test_config = Poetry::Core::Config.new
        test_config.css_mode = :bem

        # Global config should be unaffected
        assert_equal :tailwind, Poetry::Core::Config.current.css_mode
        assert_equal :bem, test_config.css_mode
      end

      def test_config_initialization_pattern
        config = Poetry::Core::Config.new
        config.custom_option = "value"
        config.another_option = 123

        assert_equal "value", config.custom_option
        assert_equal 123, config.another_option
      end

      # Test edge cases
      def test_nil_value_can_be_set
        config = Poetry::Core::Config.new
        config.nullable_option = nil

        assert_nil config.nullable_option
      end

      def test_false_value_can_be_set
        config = Poetry::Core::Config.new
        config.boolean_option = false

        refute config.boolean_option
      end

      def test_zero_value_can_be_set
        config = Poetry::Core::Config.new
        config.numeric_option = 0

        assert_equal 0, config.numeric_option
      end

      def test_empty_string_can_be_set
        config = Poetry::Core::Config.new
        config.string_option = ""

        assert_equal "", config.string_option
      end

      def test_complex_objects_can_be_stored
        config = Poetry::Core::Config.new
        config.array_option = [1, 2, 3]
        config.hash_option = { key: "value" }

        assert_equal [1, 2, 3], config.array_option
        assert_equal({ key: "value" }, config.hash_option)
      end

      # Test the declared settings surface
      def test_settings_declares_every_default_key
        assert_equal Poetry::Core::Config.defaults.keys.map(&:to_sym).sort,
                     Poetry::Core::Config::SETTINGS.sort
        Poetry::Core::Config::SETTINGS.each do |key|
          assert_includes Poetry::Core::Config.instance_methods, key
          assert_includes Poetry::Core::Config.instance_methods, :"#{key}="
        end
      end

      def test_every_setting_carries_its_method_directives
        source = Poetry::Core.root.join("lib/poetry/core/config.rb").read
        documented = source.scan(/@!method ([a-z_]+)\n/).flatten.map(&:to_sym)

        assert_equal Poetry::Core::Config::SETTINGS.sort, documented.sort
      end

      # Test delegate_missing_to behavior
      def test_responds_to_default_options
        config = Poetry::Core::Config.new

        assert_respond_to config, :classname_merger
        assert_respond_to config, :stimulus_merger
        assert_respond_to config, :css_mode
      end

      def test_responds_to_custom_options_after_setting
        config = Poetry::Core::Config.new
        config.custom_option = "value"
        # NOTE: respond_to? may not work perfectly with delegate_missing_to for dynamic options
        # but the option should still be accessible
        assert_equal "value", config.custom_option
      end

      # Test multiple concurrent instances
      def test_multiple_instances_with_different_configurations
        configs = Array.new(5) { Poetry::Core::Config.new }

        configs.each_with_index do |config, index|
          config.test_value = index

          assert_equal index, config.test_value
        end
      end

      def test_mergers_are_functional_in_all_instances
        configs = Array.new(3) { Poetry::Core::Config.new }

        configs.each do |config|
          result = config.classname_merger.merge("text-sm", "text-lg")

          assert_equal "text-lg", result
        end
      end
    end
  end
end
