# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    # The audit's analyzers, each over source strings: the inventory
    # against declared axes, the token readers, the flow edges by kind, the
    # health summary, and the check linter's call sink they read from.
    class AuditTest < Minitest::Test
      PILL = { "class_name" => "Demo::Pill::Component", "helper" => "demo_pill",
               "styles" => [{ "name" => "variant", "variants" => %w[solid soft outline], "default" => "solid" }],
               "options" => [{ "name" => "size", "type" => "symbol", "variants" => %w[sm md] },
                             { "name" => "label", "type" => "string" }],
               "slots" => [] }.freeze
      CATALOG = Check::Catalog.new({ "demo/pill" => PILL })

      def call(helper, keywords = {}, positional: nil, file: "app/views/a.html.erb", line: 1)
        Check::Call.new(helper: helper, keywords: keywords, positional: positional, file: file, line: line)
      end

      # --- the inventory ---------------------------------------------------

      def test_inventory_ranks_components_and_diffs_every_declared_axis
        calls = [call("demo_pill", { "variant" => "soft" }), call("demo_pill", { "variant" => nil }),
                 call("demo_pill", {}, file: "app/views/b.html.erb"), call("poetry_icon", {}, positional: "plus")]
        inventory = Audit::Inventory.build(calls: calls, catalog: CATALOG)

        assert_equal([["demo_pill", 3, 2], ["poetry_icon", 1, 1]],
                     inventory["components"].map { |row| row.values_at("helper", "call_sites", "files") })
        variant, size = inventory["axes"]

        assert_equal %w[solid soft], variant["used"], "the default counts when a call leaves the keyword off"
        assert_equal %w[outline], variant["unused"]
        assert_equal 1, variant["dynamic"], "a non-literal value is listed as dynamic, never guessed"
        assert_equal [], size["used"], "an option axis with no default and no literal is unexercised"
        assert_equal %w[sm md], size["unused"]
        assert_equal({ "used" => 2, "declared" => 5, "percent" => 40 }, inventory["coverage"])
      end

      def test_inventory_names_icons_from_poetry_icon_and_icon_keywords
        calls = [call("poetry_icon", {}, positional: "plus"), call("poetry_icon", { "name" => "plus" }),
                 call("poetry_icon", { "name" => "trash", "library" => "tabler" }),
                 call("demo_pill", { "icon" => "plus" }), call("demo_pill", { "icon" => nil })]

        icons = Audit::Inventory.build(calls: calls, catalog: CATALOG)["icons"]

        assert_equal([["plus", nil, 3], ["trash", "tabler", 1]], icons.map do |row|
          row.values_at("name", "library", "uses")
        end)
      end

      # --- the token readers -----------------------------------------------

      def test_tokens_count_raw_colors_off_scale_lengths_and_font_sizes
        source = <<~HTML
          <div class="bg-red-500 text-[#fff] p-[13px] md:text-[11px] text-sm">
            <span class="text-sm text-xs hover:bg-red-500 w-[0.875rem] gap-[1.5rem]">x</span>
          </div>
        HTML
        scan = Audit::Tokens.scan(source, catalog: CATALOG)

        assert_equal({ "bg-red-500" => 1, "text-[#fff]" => 1, "hover:bg-red-500" => 1 }, scan["raw_colors"])
        assert_equal({ "p-[13px]" => 1, "md:text-[11px]" => 1 }, scan["off_scale"], "half-step rems are on the scale")
        assert_equal({ "text-sm" => 2, "text-[11px]" => 1, "text-xs" => 1 }, scan["font_sizes"])
      end

      def test_tokens_aggregate_ranks_across_templates
        scan = ->(html) { Audit::Tokens.scan(html, catalog: CATALOG) }
        by_file = { "a.html.erb" => scan.call(%(<p class="bg-red-500 text-lg">x</p>)),
                    "b.html.erb" => scan.call(%(<p class="bg-red-500 text-xs text-lg">y</p>)) }
        aggregate = Audit::Tokens.aggregate(by_file)

        assert_equal [{ "token" => "bg-red-500", "uses" => 2, "files" => %w[a.html.erb b.html.erb] }],
                     aggregate["raw_colors"]
        assert_equal 2, aggregate["font_sizes"]["distinct"]
        assert_equal "b.html.erb", aggregate["font_sizes"]["templates"].first["template"]
      end

      # --- the flow edges --------------------------------------------------

      def test_edges_classify_every_target_shape_with_file_and_line
        erb = <<~ERB
          <%= link_to "Users", users_path %>
          <%= form_with(model: @user) do |f| %><% end %>
          <%= button_to "Go", "/go" %>
          <%= link_to user do %>x<% end %>
          <%= link_to "Any", polymorphic_path(record) %>
        ERB
        ruby = <<~RUBY
          class UsersController
            def create = redirect_to users_path
            def update = redirect_to @user
            def destroy = redirect_to url_for(controller: "x")
            def show = redirect_to "/users/\#{id}"
          end
        RUBY
        edges = Audit::Edges.scan(erb,
                                  file: "app/views/u.html.erb") + Audit::Edges.scan(ruby, file: "app/controllers/u.rb")

        assert_equal([["link_to", "path_helper", "users_path", 1], ["form_with", "record_or_variable", nil, 2],
                      ["button_to", "literal_path", "/go", 3], ["link_to", "record_or_variable", nil, 4],
                      ["link_to", "polymorphic", nil, 5], ["redirect_to", "path_helper", "users_path", 2],
                      ["redirect_to", "record_or_variable", nil, 3], ["redirect_to", "polymorphic", nil, 4],
                      ["redirect_to", "interpolated", nil, 5]],
                     edges.map { |edge| edge.values_at("call", "kind", "target", "line") })
        assert_equal "app/controllers/u.rb", edges.last["file"]
      end

      # --- the health summary ----------------------------------------------

      def test_health_counts_by_severity_and_rule
        findings = [Check::Finding.new(rule: "raw-color", severity: :warning, message: "m", line: 1, file: "a"),
                    Check::Finding.new(rule: "raw-color", severity: :warning, message: "m", line: 2, file: "a"),
                    Check::Finding.new(rule: "unknown-option", severity: :error, message: "m", line: 3, file: "b")]
        health = Audit::Health.summarize(findings)

        assert_equal [1, 2], health.values_at("errors", "warnings")
        assert_equal({ "raw-color" => 2, "unknown-option" => 1 }, health["by_rule"])
        assert_equal({ "rule" => "unknown-option", "severity" => :error, "message" => "m", "line" => 3, "file" => "b" },
                     health["findings"].last)
      end

      # --- the linter's call sink ------------------------------------------

      def test_the_linter_records_known_helper_calls_with_their_literals
        calls = []
        source = <<~ERB
          <%= demo_pill(variant: :soft, size: pick, label: nil, icon: "plus") { "x" } %>
          <%= poetry_icon(:trash) %>
          <%= demo_pill(variant: :outline) { "y" } %>
        ERB
        Check::Linter.new(CATALOG).lint(source, calls: calls)

        assert_equal [["demo_pill", 1, { "variant" => "soft", "size" => nil, "icon" => "plus" }, nil],
                      ["demo_pill", 3, { "variant" => "outline" }, nil]],
                     calls.map { |call| [call.helper, call.line, call.keywords, call.positional] },
                     "a literal nil is not passed; a dynamic value is nil; an unknown helper is a finding, not a call"
      end

      def test_the_runner_stamps_each_call_with_its_file
        Dir.mktmpdir("audit-sink") do |dir|
          path = File.join(dir, "a.html.erb")
          File.write(path, %(<%= demo_pill(variant: :soft) { "x" } %>))
          calls = []
          Check::Runner.new(CATALOG).run([path], calls: calls)

          assert_equal [path], calls.map(&:file)
        end
      end
    end
  end
end
