# frozen_string_literal: true

require "test_helper"

# installed by the poetry `screen-settings` recipe. The composed screen
# renders all three blocks. That is the server's HTML, so no browser is
# needed: an integration test, which runs with `bin/rails test`.
class SettingsShowTest < ActionDispatch::IntegrationTest
  test "the settings page composes header, section, and danger zone" do
    get settings_path

    assert_response :success
    assert_includes response.body, "Atlas"
    assert_includes response.body, "Usage-based billing"
    assert_includes response.body, "Revoke deploy token"
  end
end
