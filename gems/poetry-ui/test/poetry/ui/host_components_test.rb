# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # A host application's own component (test/dummy's Demo::Badge, on
    # the DSL with `helper :demo_badge`) is first-class on the booted
    # surfaces: its helper renders, poetry check lints it under its own
    # name, llms-full.txt carries its contract and agent rules, and the
    # generated skill gives it a reference file.
    class HostComponentsTest < ActionDispatch::IntegrationTest
      def test_the_declared_helper_renders_the_component
        html = ApplicationController.render(inline: %(<%= demo_badge(tone: :loud) { "New" } %>))

        assert_includes html, "New"
        assert_includes html, "demo-badge-loud"
      end

      def test_poetry_check_lints_the_app_component_under_its_own_name
        host = Poetry::Core::HostComponents.registry(root: Rails.root)
        catalog = Poetry::Core::Check::Catalog.from_registries([Poetry::Ui.root],
                                                               helpers: Poetry::Ui.helper_names + host.helper_args.keys,
                                                               host_registry: host)
        findings = Poetry::Core::Check.lint(<<~ERB, catalog: catalog)
          <%= demo_badge(tone: :loud) { "ok" } %>
          <%= demo_badge(tone: :nope) { "x" } %>
          <%= demo_badge "positional" %>
        ERB

        assert_equal %w[unknown-variant helper-arity], findings.map(&:rule)
        assert_match(/is not a demo_badge tone/, findings.first.message)
      end

      def test_llms_full_txt_carries_the_app_component
        get "/llms-full.txt"

        assert_response :success
        assert_includes response.body, "## App components"
        assert_includes response.body, "## demo_badge (`demo_badge`)"
        assert_includes response.body, "- RULE: Demo badges are read-only labels; never attach click handlers."
        get "/llms.txt"

        assert_includes response.body, "- demo_badge: `demo_badge` - tone: neutral|loud"
      end

      def test_the_generated_skill_carries_an_app_reference
        files = Poetry::Ui.skill_files(host_registry: Poetry::Core::HostComponents.registry(root: Rails.root))

        assert_includes files.fetch("references/app.md"), "## demo_badge (`demo_badge`)"
        assert_includes files.fetch("SKILL.md"), "- **app** (`references/app.md`): demo_badge"
      end
    end
  end
end
