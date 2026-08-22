# frozen_string_literal: true

require "application_system_test_case"

# installed by the poetry `screen-settings` recipe. Server-render
# assertions only - no JS driver required; the test proves the composed
# screen renders all three blocks.
class SettingsShowTest < ApplicationSystemTestCase
  test "the settings page composes header, section, and danger zone" do
    visit settings_path

    assert_text "Atlas"
    assert_text "Usage-based billing"
    assert_text "Revoke deploy token"
  end
end
