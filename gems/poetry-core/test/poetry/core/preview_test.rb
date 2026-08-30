# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Poetry
  module Core
    # Core-level pins for the preview stack (naming, abstract filtering,
    # template rung resolution, component inference) - previously covered
    # only indirectly through poetry-ui's preview-rendering gates.
    class PreviewTest < Minitest::Test
      # The X::Preview naming convention (sidecar preview.rb files).
      module Glow
        class Component < Poetry::Core::Component
          def call = content_tag(:span, "glow")
        end

        class Preview < Poetry::Core::Preview::Base
          def default = render_component
        end
      end

      # The FooPreview suffix convention, with the two other inference
      # shapes: a bare class and a Component-suffixed class.
      class GadgetComponent < Poetry::Core::Component
        def call = content_tag(:span, "gadget")
      end

      class GadgetPreview < Poetry::Core::Preview::Base
        def default = render_component
      end

      # A component whose constructor raises - the build-error path.
      module Fussy
        class Component < Poetry::Core::Component
          def initialize
            super
            raise ArgumentError, "always unhappy"
          end
        end

        class Preview < Poetry::Core::Preview::Base
          def default = render_with(note: "built without a component local")
        end
      end

      def test_preview_name_handles_both_suffix_conventions
        assert_equal "poetry/core/preview_test/glow", Glow::Preview.preview_name
        assert_equal "poetry/core/preview_test/gadget", GadgetPreview.preview_name
      end

      def test_all_filters_abstract_classes
        all = ViewComponent::Preview.all

        assert_includes all, Glow::Preview
        refute_includes all, Poetry::Core::Preview::Base, "the base marks itself abstract"
      end

      def test_the_loader_pairing_is_wired
        assert_respond_to ViewComponent::Preview, :load_previews,
                          "Abstract#all delegates loading to Sidecarable - the engine wires both"
      end

      def test_component_class_name_infers_all_three_conventions
        assert_equal "Poetry::Core::PreviewTest::Glow::Component", Glow::Preview.component_class_name
        assert_equal "Poetry::Core::PreviewTest::GadgetComponent", GadgetPreview.component_class_name
      end

      def test_render_args_builds_the_component_and_container_locals
        args = Glow::Preview.render_args("default")

        assert_equal "poetry/core/preview", args[:template], "no sidecar template falls back to the default"
        assert_instance_of Glow::Component, args[:locals][:component]
        assert_equal "", args[:locals][:container_class]
      end

      def test_render_args_surfaces_the_build_error_instead_of_raising
        args = Fussy::Preview.render_args("default")

        assert_nil args[:locals][:component]
        assert_includes args[:locals][:error], "always unhappy"
      end

      def test_template_resolution_walks_the_sidecar_rungs
        Dir.mktmpdir do |dir|
          probe = Class.new(Poetry::Core::Preview::Base)
          Poetry::Core::PreviewTest.const_set(:RungProbePreview, probe)
          probe.define_singleton_method(:preview_paths) { [dir] }
          name = probe.preview_name

          # Rung 4: nothing on disk -> the default template.
          assert_equal "poetry/core/preview", probe.preview_example_template_path("default")

          # Rung 3: a shared preview.html.* for the whole preview class.
          FileUtils.mkdir_p(File.join(dir, name))
          File.write(File.join(dir, name, "preview.html.erb"), "shared")

          assert_equal File.join(name, "preview"), probe.preview_example_template_path("default")

          # Rung 2: an example-specific previews/<example>.html.* wins.
          FileUtils.mkdir_p(File.join(dir, name, "previews"))
          File.write(File.join(dir, name, "previews", "default.html.erb"), "specific")

          assert_equal File.join(name, "previews", "default"), probe.preview_example_template_path("default")
        ensure
          Poetry::Core::PreviewTest.send(:remove_const, :RungProbePreview)
        end
      end

      def test_load_previews_requires_sidecar_files_from_preview_paths
        Dir.mktmpdir do |dir|
          FileUtils.mkdir_p(File.join(dir, "sample"))
          File.write(File.join(dir, "sample", "preview.rb"), "POETRY_PREVIEW_LOAD_MARKER = true\n")
          probe = Class.new(Poetry::Core::Preview::Base)
          probe.define_singleton_method(:preview_paths) { [dir] }

          probe.load_previews

          assert defined?(POETRY_PREVIEW_LOAD_MARKER), "the sidecar glob must require preview.rb files"
        ensure
          Object.send(:remove_const, :POETRY_PREVIEW_LOAD_MARKER) if defined?(POETRY_PREVIEW_LOAD_MARKER)
        end
      end
    end
  end
end
