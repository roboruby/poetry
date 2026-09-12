# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The override audit's ownership set: gem dictionaries plus the
    # installed fragment; a host kit's classes are never in it.
    class ThemeOwnedNamesTest < ActiveSupport::TestCase
      test "the theme-owned set holds the gem dictionaries and the fragment's own names, not a host kit's" do
        Rails.application.eager_load!
        owned = Poetry::Ui.theme_owned_names(theme_css: Poetry::Ui.root.join("themes/default.css").read)

        assert_includes owned, "cn-button"
        assert_includes owned, "cn-alert-title"
        assert_includes owned, "cn-font-heading", "a consumer utility the fragment defines on purpose"
        refute_includes owned, "cn-acme-pill"
        scan = Poetry::Core::CSS::OverrideScan.new(
          sources: { "app/assets/kit.css" => ".cn-acme-pill { color: red; } .cn-button { color: red; }" },
          declarations: [], owned: owned
        )

        assert_equal [["app/assets/kit.css", ["cn-button"]]], scan.undeclared
      end
    end
  end
end
