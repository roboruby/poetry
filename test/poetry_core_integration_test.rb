# frozen_string_literal: true

require "test_helper"

# Smoke test: poetry-core loads and its framework layer is usable through the
# poetry umbrella. Component rendering needs a booted Rails host and is covered
# by poetry-core's own test/dummy suite (app/components autoloads only once the
# engine is mounted in a host); here we verify the integration cold.
class PoetryCoreIntegrationTest < Minitest::Test
  def test_requiring_poetry_loads_the_library_proper
    assert defined?(Poetry::Core), "require poetry should load Poetry::Core"
    assert defined?(Poetry::Ui), "require poetry should load Poetry::Ui"
    assert defined?(Poetry::Lucide), "require poetry should load Poetry::Lucide"
  end

  def test_engine_resolves_as_a_rails_engine
    assert_operator Poetry::Core::Engine, :<, Rails::Engine
  end

  def test_config_is_a_singleton
    assert_same Poetry::Core::Config.current, Poetry::Core::Config.current
  end

  def test_stimulus_builder_formats_namespaced_identifiers
    assert_equal "admin--dropdown",
                 Poetry::Core::Stimulus::Builder.format_identifier(%i[admin dropdown])
  end
end
