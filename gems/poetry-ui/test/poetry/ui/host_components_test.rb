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
        assert_includes html, "bg-primary"
      end

      # The three shapes 0.1.2's check misread on a real host: a composed
      # trigger's wiring param, the webmcp form's builder, and a helper
      # method the app defines under the prefix.
      def test_poetry_check_reads_the_composed_trigger_the_webmcp_form_and_a_host_helper_method
        catalog = Poetry::Core::Check::Catalog.from_registry(Poetry::Ui.root, host_helpers: ["poetry_pagy_nav"])
        findings = Poetry::Core::Check.lint(<<~ERB, catalog: catalog)
          <%= poetry_tooltip do |tooltip| %>
            <% tooltip.with_trigger(compose: true) do |wiring| %><span <%= wiring %>>x</span><% end %>
          <% end %>
          <%= poetry_webmcp_form(url: "/q", method: :get, tool: { name: "search", description: "Search.", autosubmit: true }) do |form| %>
            <%= form.field(:q) %>
          <% end %>
          <%= poetry_pagy_nav(@pagy, edges: :icons) %>
        ERB

        assert_empty findings.map(&:message).grep(/yields nothing|no poetry component/)
        findings = Poetry::Core::Check.lint(<<~ERB, catalog: Poetry::Core::Check::Catalog.from_registry(Poetry::Ui.root))
          <%= poetry_tooltip do |tooltip| %>
            <% tooltip.with_trigger do |wiring| %>x<% end %>
          <% end %>
          <%= poetry_pagy_nav(@pagy) %>
        ERB

        heads = findings.map(&:message).grep(/yields nothing|no poetry component/).map { |m| m[/^[^-(]+/].strip }

        assert_equal ["with_trigger yields nothing to its block", "no poetry component poetry_pagy_nav"], heads
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

      def test_registry_roots_are_found_by_convention_and_carry_every_gem_helper
        roots = Poetry::Core::Registry.roots.map(&:to_s)

        assert_includes roots, Poetry::Ui.root.to_s
        refute_includes roots, Poetry::Core.root.to_s, "poetry-core's registry is internal"
        # The invariant poetry:check relies on when it names no gem: the
        # registries' own sections carry every helper the gem defines.
        catalog = Poetry::Core::Check::Catalog.from_registries(Poetry::Core::Registry.roots)

        assert_empty Poetry::Ui.helper_names - catalog.helper_names
      end

      def test_poetry_registry_writes_the_app_file_the_boot_free_surfaces_read
        Dir.mktmpdir do |root|
          path = Poetry::Core::HostComponents.registry(root: root).generate!

          assert_equal :fresh, Poetry::Core::HostComponents.committed_state(root: root)
          assert Poetry::Core::Registry.published_at?(root)
          committed = Poetry::Core::Registry.committed(root)

          assert_equal "demo_badge", committed.entries.dig("demo/badge", "helper")
          assert_includes Poetry::Ui.agent_skills(app_root: root).fetch("poetry").call.fetch("references/app.md"),
                          "## demo_badge (`demo_badge`)"
          assert_includes Poetry::Core::Registry.gem_roots(app_root: root).map(&:to_s), root
          path.write("#{path.read}# edited\n")

          assert_equal :stale, Poetry::Core::HostComponents.committed_state(root: root)
        end
      end

      def test_the_generated_skill_carries_an_app_reference
        files = Poetry::Ui.skill_files(host_registry: Poetry::Core::HostComponents.registry(root: Rails.root))

        assert_includes files.fetch("references/app.md"), "## demo_badge (`demo_badge`)"
        assert_includes files.fetch("SKILL.md"), "- **app** (`references/app.md`): demo_badge"
      end
    end
  end
end
