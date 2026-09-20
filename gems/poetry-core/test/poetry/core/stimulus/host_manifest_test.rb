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
        # The shapes host controllers are actually written in (one-line
        # bodies, arrow fields, braces inside literals and comments, comments
        # inside statics, CRLF, a BOM, a helper class above the export).
        SHAPES_ROOT = Pathname.new(File.expand_path("../../../fixtures/host_shapes", __dir__))

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

        def test_reads_the_shapes_controllers_are_written_in
          read = HostManifest.scan(root: SHAPES_ROOT).definitions

          assert_equal %w[a b], read.fetch("one-line")["targets"], "one-line statics"
          assert_equal ["pulse"], read.fetch("one-line")["methods"], "a one-line method body"
          methods = read.fetch("methods")["methods"]

          %w[connect pulse fetchIt arrow arrowWithArgs allman multiParam].each do |name|
            assert_includes methods, name
          end
          refute_includes methods, "count", "an accessor is not an action"
          refute_includes methods, "tick", "a private #method is not an action"
          %w[brace-in-comment brace-in-string regex-brace].each do |id|
            assert_equal %w[before after], read.fetch(id)["methods"], "#{id}: a brace inside a literal or a comment"
          end
          assert_equal({ "tone" => { "type" => "String" }, "limit" => { "type" => "Number", "default" => 3 },
                         "url" => { "type" => "String" } },
                       read.fetch("values-comment")["values"], "comments inside static values")
          assert_equal "}", read.fetch("values-string-brace")["values"]["open"]["default"]
          assert_equal ["pulse"], read.fetch("crlf")["methods"]
          assert_equal ["pulse"], read.fetch("bom")["methods"]
          assert_equal ["pulse"], read.fetch("class-then-export")["methods"]
          assert_equal %w[ping pulse], read.fetch("two-classes")["methods"],
                       "the default export, not the helper class above it"
          assert_equal %w[submit pulse], read.fetch("comment-extends")["methods"],
                       "the real parent, not one named in a comment"
          refute read.fetch("dispatcher").key?("events"), "no static events: events stay unknown, never []"
        end

        def test_a_static_the_reader_cannot_read_is_a_named_skip_never_a_partial_entry
          result = HostManifest.scan(root: SHAPES_ROOT)
          reasons = result.skipped.to_h { |skip| [skip.identifier, skip.reason] }

          assert_match(/getter/, reasons.fetch("getter-targets"))
          assert_match(/spread or a template/, reasons.fetch("spread"))
          assert_match(/spread or a template/, reasons.fetch("template-literal"))
          %w[getter-targets spread template-literal].each { |id| refute result.definitions.key?(id) }
        end

        # The gem's own controllers against the manifest the Node generator
        # introspected from the real classes: everything the classes carry,
        # the reader carries (accessors and Stimulus's own callbacks aside,
        # by policy; a computed `static events` stays unknown).
        def test_reads_the_gem_s_own_controllers_like_the_generator_does
          truth = JSON.parse(Poetry::Core.root.join("config/controllers_manifest.json").read)
          dir = Poetry::Core.root.join("app/javascript/poetry/core")
          compared = 0
          Dir.glob(dir.join("*_controller.js").to_s).each do |file|
            identifier = "poetry--core--#{HostManifest.identifier_for(File.basename(file))}"
            expected = truth[identifier]
            next unless expected

            compared += 1
            read = HostManifest.resolve(file, [])

            assert_equal expected["targets"].sort, read["targets"].sort, "#{identifier} targets"
            assert_equal expected["classes"].sort, read["classes"].sort, "#{identifier} classes"
            # The generator also harvests each value's prose (and the reader inherits it
            # through the catalog for a parent's values); the shapes are what must agree.
            shape = ->(values) { values.transform_values { |value| value.except("doc") } }

            assert_equal shape.call(expected["values"]), shape.call(read["values"]), "#{identifier} values"
            missing = expected["methods"].grep_v(HostManifest::CALLBACK) - read["methods"]

            assert_empty missing, "#{identifier} methods the generator found and the reader did not"
            assert_equal expected["events"].sort, read["events"].sort, "#{identifier} events" if read.key?("events")
          end

          assert_operator compared, :>=, 50
        end

        def test_a_hand_written_entry_survives_regeneration_and_never_reads_stale
          Dir.mktmpdir do |root|
            dir = File.join(root, HostManifest::CONTROLLERS_DIR)
            FileUtils.mkdir_p(dir)
            FileUtils.cp(FIXTURE_ROOT.join("app/javascript/controllers/demo_badge_controller.js"), dir)
            HostManifest.generate!(root: root)
            path = Pathname.new(root).join(HostManifest::RELATIVE_PATH)
            entries = JSON.parse(path.read)
            entries["fancy"] = { "targets" => ["panel"], "values" => {}, "classes" => [], "methods" => ["open"] }
            path.write("#{JSON.pretty_generate(entries, indent: "    ")}\r\n")

            assert_equal :fresh, HostManifest.state(root: root), "a hand entry, re-indented and CRLF, is not staleness"
            HostManifest.generate!(root: root)

            assert_equal ["open"], JSON.parse(path.read).fetch("fancy")["methods"], "regeneration keeps the hand entry"
            assert_equal %w[demo-badge fancy], JSON.parse(path.read).keys
          end
        end

        def test_an_unreadable_committed_file_reads_stale_and_regenerates
          Dir.mktmpdir do |root|
            FileUtils.mkdir_p(File.join(root, HostManifest::CONTROLLERS_DIR))
            path = Pathname.new(root).join(HostManifest::RELATIVE_PATH)
            path.dirname.mkpath
            path.write("{ not json")

            assert_equal :stale, HostManifest.state(root: root)
            HostManifest.generate!(root: root)

            assert_equal({}, JSON.parse(path.read))
          end
        end

        def test_a_stray_byte_does_not_abort_the_read
          Dir.mktmpdir do |root|
            dir = File.join(root, HostManifest::CONTROLLERS_DIR)
            FileUtils.mkdir_p(dir)
            File.binwrite(File.join(dir, "latin_controller.js"),
                          "import { Controller } from \"@hotwired/stimulus\"\n// caf\xE9\n" \
                          "export default class extends Controller {\n  pulse() {}\n}\n")

            assert_equal ["pulse"], HostManifest.scan(root: root).definitions.fetch("latin")["methods"]
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
