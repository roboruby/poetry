# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # A host controller with a manifest entry validates like poetry's: the
    # DSL at class load (Symbol identifiers resolve), the check in
    # templates, the registry's controllers section. The dummy's
    # demo-badge entry is registered here from the generated file, and
    # forgotten after.
    class HostControllersTest < ActiveSupport::TestCase
      def setup
        @dir = Dir.mktmpdir("host-manifest")
        FileUtils.mkdir_p(File.join(@dir, Poetry::Core::Stimulus::HostManifest::CONTROLLERS_DIR))
        FileUtils.cp(Rails.root.join("app/javascript/controllers/demo_badge_controller.js"),
                     File.join(@dir, Poetry::Core::Stimulus::HostManifest::CONTROLLERS_DIR))
        Poetry::Core::Stimulus::HostManifest.generate!(root: @dir)
        Poetry::Core::Stimulus::Manifest.register_roots([@dir])
      end

      def teardown
        Poetry::Core::Stimulus::Manifest.forget("demo-badge")
        FileUtils.rm_rf(@dir)
      end

      test "use_stimulus validates a host controller by Symbol once its manifest is registered" do
        wired = Class.new(Poetry::Core::Component) do
          use_stimulus do
            on :root do
              controller(:demo_badge) do
                register
                value :tone, :loud
                target :label
                action :pulse
              end
            end
          end
        end

        assert_equal "demo-badge", wired.stimulus_definitions.first["controllers"].first["identifier"]
        error = assert_raises(Poetry::Core::Stimulus::Declarations::DeclarationError) do
          Class.new(Poetry::Core::Component) do
            use_stimulus do
              on :root do
                controller(:demo_badge) { target :nope }
              end
            end
          end
        end

        assert_match(/unknown target "nope" for demo-badge/, error.message)
      end

      test "poetry check validates a host controller's wiring in templates" do
        catalog = Poetry::Core::Check::Catalog.new({})
        findings = Poetry::Core::Check.lint(<<~ERB, catalog: catalog)
          <div data-controller="demo-badge" data-action="click->demo-badge#nope" data-demo-badge-tone-value="loud" data-demo-badge-size-value="1"></div>
        ERB

        assert_equal %w[unknown-action unknown-value], findings.map(&:rule).sort
        assert_match(/demo-badge has no value "size"/, findings.find { |f| f.rule == "unknown-value" }.message)
      end

      # A named probe: the registry reads a class's source location.
      module Wired
        class Component < Poetry::Core::Component
          use_stimulus do
            on :root do
              controller("demo-badge") { register }
            end
          end

          def call
            content_tag(:div, "w")
          end
        end
      end

      test "the registry's controllers section carries the host controller's API" do
        entry = Poetry::Core::Registry.new(components: [Wired::Component], source_root: Rails.root).entries.values.first

        assert_equal ["pulse"], entry["controllers"].first["actions"]
        assert_equal ["demo:badge:pulse"], entry["controllers"].first["events"]
      ensure
        Poetry::Core::HostHelpers.sync!([]) if defined?(Poetry::Core::HostHelpers)
      end
    end
  end
end
