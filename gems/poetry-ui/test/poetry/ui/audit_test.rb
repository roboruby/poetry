# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Poetry
  module Ui
    # The audit over the dummy app: the four files and the report, their
    # headline numbers against what the dummy's views contain.
    class AuditTest < ActiveSupport::TestCase
      def audit
        @audit ||= Audit.new(root: Rails.root, catalog: CheckCatalog.build(root: Rails.root),
                             routes: Audit.routes_from(Rails.application.routes), app: "Dummy").tap(&:run)
      end

      def test_routes_from_keeps_routes_with_a_controller_and_drops_mounts
        routes = Audit.routes_from(Rails.application.routes)
        mgate = routes.find { |route| route["path"] == "/mgate" && route["verb"] == "GET" }

        assert_equal({ "controller" => "morph_state_gate", "action" => "index" }, mgate.slice("controller", "action"))
        assert(routes.none? { |route| route["controller"].nil? })
      end

      def test_the_inventory_reads_the_dummy_views_against_the_catalog
        summary = audit.data["summary"]
        helpers = audit.data["inventory"]["components"].map { |row| row["helper"] }

        assert_includes helpers, "poetry_tabs"
        assert_includes helpers, "poetry_collapsible"
        assert_operator summary["coverage"]["declared"], :>, summary["coverage"]["used"]
        menu = audit.data["inventory"]["axes"].find { |axis| axis["helper"] == "poetry_dropdown_menu" }

        assert menu, "a used component's variant axes are listed"
        assert_operator menu["declared"].size, :>, 0
      end

      def test_flows_resolve_the_gate_form_to_its_route_and_list_the_page
        flows = audit.data["flows"]
        form = flows["edges"].find { |edge| edge["file"] == "app/views/morph_state_gate/index.html.erb" }

        assert_equal ["form_with", "literal_path", "/mgate", "morph_state_gate#save"],
                     form.values_at("call", "kind", "target", "to")
        page = flows["pages"].find { |row| row["template"] == "app/views/morph_state_gate/index.html.erb" }

        assert_includes page["components"].map { |row| row["helper"] }, "poetry_dialog"
        assert flows["partials"]["available"], "the render analyzer ran: #{flows["partials"]["reason"]}"
      end

      def test_write_lands_the_files_whole_and_the_report_renders_poetry_components
        Dir.mktmpdir("poetry-audit") do |dir|
          files = audit.write(dir)

          assert_equal %w[flows.json health.json inventory.json report.html summary.json],
                       files.map { |file| file.basename.to_s }.sort
          summary = JSON.parse(File.read(files.first))
          report = File.read(files.last)

          assert_equal Audit::SCHEMA, summary["schema"]
          assert_includes report, "<title>Poetry audit: Dummy</title>"
          assert_includes report, 'data-slot="stat"'
          assert_includes report, "poetry_tabs"
          assert_empty Dir.glob(File.join(dir, "*.tmp"))
        end
      end

      def test_the_summary_text_names_every_section
        text = audit.summary_text

        %w[components health paint icons partials flows].each { |section| assert_includes text, "  #{section}" }
      end
    end
  end
end
