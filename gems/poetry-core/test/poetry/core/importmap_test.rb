# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    # Keeps the importmap channel honest: every asset the engine's
    # config/importmap.rb pins must exist on disk, and every shipped JS file
    # must be reachable via the pinned tree - so a file move can't silently
    # 404 under an importmap host while the npm channel keeps working.
    class ImportmapTest < Minitest::Test
      JS_ROOT = Poetry::Core.root.join("app/javascript")

      def test_the_entrypoint_pin_targets_a_real_file
        importmap = Poetry::Core.root.join("config/importmap.rb").read
        entry = importmap[%r{pin "@poetry/controllers", to: "([^"]+)"}, 1]

        refute_nil entry
        assert_path_exists JS_ROOT.join(entry)
      end

      def test_pin_all_from_covers_the_whole_shipped_tree
        importmap = Poetry::Core.root.join("config/importmap.rb").read

        assert_includes importmap, %(under: "@poetry/controllers")
        assert_includes importmap, %(to: "poetry/core")
        assert_path_exists JS_ROOT.join("poetry/core")
      end

      def test_a_gem_serves_its_minified_tree_when_it_carries_one
        Dir.mktmpdir do |gem_root|
          gem_root = Pathname.new(gem_root)

          assert_equal gem_root.join("app/javascript"), Poetry::Core.javascript_path(gem_root)

          gem_root.join("dist/javascript").mkpath

          assert_equal gem_root.join("dist/javascript"), Poetry::Core.javascript_path(gem_root.to_s)
        end
      end

      def test_the_repository_serves_source
        # dist/ exists only while the release builds a gem; a stray one would
        # put every dev and test host on minified code.
        assert_equal JS_ROOT, Poetry::Core.javascript_path(Poetry::Core.root)
      end

      def test_internal_imports_use_the_dual_channel_specifier
        # Relative imports break under Propshaft digests; bare
        # "@poetry/controllers/..." specifiers resolve under BOTH channels
        # (pin_all_from + the package exports map).
        offenders = Dir.glob("#{JS_ROOT}/**/*.js").select do |file|
          File.read(file).match?(%r{^import .* from "\.\.?/})
        end

        assert_empty offenders, "use @poetry/controllers/... specifiers, not relative imports: #{offenders}"
      end
    end
  end
end
