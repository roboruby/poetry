# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The Lookbook surface (mounted at /lookbook in the dummy): the same
    # sidecar preview corpus the browser gates screenshot, browsable with
    # param controls and source panes - "one corpus, three uses" made real.
    class LookbookTest < ActionDispatch::IntegrationTest
      test "lookbook serves its browser shell" do
        get "/lookbook"

        assert_response :success
      end

      test "a component preview renders through lookbook with poetry styling hooks" do
        # The preview corpus @!groups its methods, so scenarios address by
        # group name (button's default/destructive/... render as variants).
        get "/lookbook/preview/poetry/ui/button/variants"

        assert_response :success
        assert_match(/data-slot="button"/, response.body)
        assert_match(/Save changes/, response.body)
      end

      test "the engines feed lookbook the full sidecar corpus" do
        # Every gem preview path registered by the engines' setup_lookbook
        # initializers (ui + core here; charts joins in hosts that load it).
        paths = Rails.application.config.lookbook.preview_paths.map(&:to_s)

        assert_includes paths, "#{Poetry::Ui.root}/app/components"
        assert_includes paths, "#{Poetry::Core.root}/app/components"
      end
    end
  end
end
