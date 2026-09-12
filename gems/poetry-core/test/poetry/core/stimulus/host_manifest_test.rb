# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Poetry
  module Core
    module Stimulus
      # The host controllers manifest: read from sources, complete or
      # absent, merged child-first, registered like a gem's.
      class HostManifestTest < Minitest::Test
        FIXTURE_ROOT = Pathname.new(File.expand_path("../../../fixtures/host_app", __dir__))

        def test_identifiers_follow_the_stimulus_convention
          assert_equal "demo-badge", HostManifest.identifier_for("demo_badge_controller.js")
          assert_equal "admin--audit-log", HostManifest.identifier_for("admin/audit_log_controller.js")
        end

        def test_reads_every_static_shape_and_the_class_body_s_own_methods
          entry = HostManifest.scan(root: FIXTURE_ROOT).definitions.fetch("demo-badge")

          assert_equal %w[label count], entry["targets"]
          assert_equal({ "tone" => { "type" => "String" },
                         "limit" => { "type" => "Number", "default" => 3 },
                         "open" => { "type" => "Boolean", "default" => false },
                         "tags" => { "type" => "Array", "default" => [] } }, entry["values"])
          assert_equal ["active"], entry["classes"]
          assert_equal ["demo:badge:pulse"], entry["events"]
          assert_equal %w[connect disconnect pulse refresh], entry["methods"],
                       "lifecycle in, private #tick and the loud accessor out, no control-flow keywords"
        end

        def test_a_child_of_a_host_controller_merges_its_parent_child_first
          entry = HostManifest.scan(root: FIXTURE_ROOT).definitions.fetch("invoice-form")

          assert_equal %w[submit total], entry["targets"]
          assert_equal({ "type" => "String", "default" => "/invoices" }, entry["values"]["url"], "the child wins")
          assert_equal({ "type" => "String" }, entry["values"]["currency"])
          assert_equal %w[submit recalculate], entry["methods"]
        end

        def test_a_child_of_a_poetry_controller_merges_the_catalog_entry
          entry = HostManifest.scan(root: FIXTURE_ROOT).definitions.fetch("fancy-dialog")
          dialog = Manifest.catalog.fetch("poetry--core--dialog")

          assert_includes entry["targets"], "confetti"
          assert_equal (dialog["targets"] + ["confetti"]).uniq, entry["targets"]
          assert_includes entry["methods"], "celebrate"
          assert_includes entry["methods"], "open"
        end

        def test_an_unresolvable_parent_yields_no_entry_and_a_named_skip
          result = HostManifest.scan(root: FIXTURE_ROOT)

          refute result.definitions.key?("fancy")
          skip = result.skipped.find { |s| s.identifier == "fancy" }

          assert_match(%r{extends SomeLibController from some-lib/controller, which the reader cannot follow},
                       skip.reason)
        end

        def test_generate_writes_the_file_and_state_tracks_it
          Dir.mktmpdir do |root|
            dir = File.join(root, HostManifest::CONTROLLERS_DIR)
            FileUtils.mkdir_p(dir)
            FileUtils.cp(FIXTURE_ROOT.join("app/javascript/controllers/demo_badge_controller.js"), dir)

            assert_equal :missing, HostManifest.state(root: root)
            result = HostManifest.generate!(root: root)

            assert_equal ["demo-badge"], result.definitions.keys
            assert_equal :fresh, HostManifest.state(root: root)
            assert_equal ["demo-badge"], JSON.parse(result.path.read).keys
            File.write(File.join(dir, "demo_badge_controller.js"), <<~JS)
              import { Controller } from "@hotwired/stimulus"
              export default class extends Controller {
                static targets = ["other"]
              }
            JS

            assert_equal :stale, HostManifest.state(root: root)
          end
        end

        def test_register_roots_merges_a_host_manifest_and_skips_core_s_own
          Dir.mktmpdir do |root|
            HostManifest.generate!(root: root.tap do |r|
              FileUtils.mkdir_p(File.join(r, HostManifest::CONTROLLERS_DIR))
            end)
            File.write(File.join(root, HostManifest::RELATIVE_PATH),
                       { "acme--thing" => { "targets" => ["x"], "values" => {}, "classes" => [], "methods" => ["go"],
                                            "events" => [] } }.to_json)
            registered = Manifest.register_roots([Poetry::Core.root, root])

            assert_equal [Pathname.new(root).join(HostManifest::RELATIVE_PATH)], registered
            assert_equal ["x"], Manifest.definition("acme--thing")["targets"]
          ensure
            Manifest.forget("acme--thing")
          end
        end
      end
    end
  end
end
