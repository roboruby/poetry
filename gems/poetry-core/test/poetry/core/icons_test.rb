# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    # Icons.suggest and the FileSet error surface: the reversed-
    # compound Lucide renames resolve, edit distance still works, and the
    # runtime unknown-icon error names the fix.
    class IconsTest < Minitest::Test
      def test_suggest_bridges_the_reversed_compound_renames
        assert_equal "circle-alert", Icons.suggest(:"alert-circle", %w[circle-alert circle-x])
        assert_equal "circle-x", Icons.suggest("x-circle", %w[circle-alert circle-x])
      end

      def test_suggest_falls_back_to_edit_distance
        assert_equal "circle-alert", Icons.suggest("cirle-alert", %w[circle-alert circle-x])
      end

      def test_suggest_tolerates_underscores_and_returns_nil_when_nothing_is_close
        assert_equal "circle-alert", Icons.suggest(:alert_circle, %w[circle-alert])
        assert_nil Icons.suggest("zzzz", %w[circle-alert])
      end

      def test_fetch_names_the_closest_icon_in_the_unknown_error
        Dir.mktmpdir("icons") do |dir|
          File.write(File.join(dir, "circle-alert.svg"), %(<path d="M0 0"/>))
          set = Icons::FileSet.new(dir: dir)

          error = assert_raises(IconNotFound) { set.fetch(:"alert-circle") }

          assert_kind_of Poetry::Core::Error, error
          assert_includes error.message, %(did you mean :"circle-alert"?)
          assert_equal :"alert-circle", error.name
          assert_equal "circle-alert", error.suggestion
        end
      end

      def test_fetch_stays_terse_when_nothing_is_close
        Dir.mktmpdir("icons") do |dir|
          File.write(File.join(dir, "circle-alert.svg"), "<path/>")
          set = Icons::FileSet.new(dir: dir)

          error = assert_raises(IconNotFound) { set.fetch(:zzzz) }

          refute_includes error.message, "did you mean"
          assert_nil error.suggestion
        end
      end

      def test_a_set_draws_with_lucides_stroke_unless_it_names_its_own
        Dir.mktmpdir("icons") do |dir|
          assert_equal Icons::DEFAULT_SVG_ATTRIBUTES, Icons::FileSet.new(dir: dir).svg_attributes

          filled = { "viewBox" => "0 0 256 256", "fill" => "currentColor" }

          assert_equal filled, Icons::FileSet.new(dir: dir, svg_attributes: filled).svg_attributes
        end
      end

      def test_a_packed_set_serves_each_line_by_name
        Dir.mktmpdir("icons") do |dir|
          path = File.join(dir, "set.tsv")
          File.write(path, Icons::Vendor.packed("house" => %(<path d="M1"/>), "a-z" => %(<path d="é"/>)))
          set = Icons::PackedSet.new(path: path, svg_attributes: { "fill" => "currentColor" })

          assert_equal %i[a-z house], set.names
          assert_equal %(<path d="M1"/>), set.fetch(:house)
          assert_equal %(<path d="é"/>), set.fetch("a-z")
          assert_includes set, :house
          refute_includes set, :"house-2"
          refute_includes set, "../set"
          assert_equal({ "fill" => "currentColor" }, set.svg_attributes)
        end
      end

      def test_a_packed_set_raises_the_same_errors_as_a_file_set
        Dir.mktmpdir("icons") do |dir|
          path = File.join(dir, "set.tsv")
          File.write(path, Icons::Vendor.packed("circle-alert" => "<path/>"))
          set = Icons::PackedSet.new(path: path)

          unknown = assert_raises(IconNotFound) { set.fetch(:"alert-circle") }
          malformed = assert_raises(IconNotFound) { set.fetch("../etc") }

          assert_equal "circle-alert", unknown.suggestion
          assert_includes malformed.message, "invalid icon name"
        end
      end

      def test_an_alias_renders_its_current_icon_in_either_kind_of_set
        Dir.mktmpdir("icons") do |dir|
          File.write(File.join(dir, "trash.svg"), %(<path d="M3 6h18"/>))
          packed = File.join(dir, "set.tsv")
          File.write(packed, Icons::Vendor.packed("trash" => %(<path d="M3 6h18"/>)))
          sets = [Icons::FileSet.new(dir: dir, aliases: { "trash-2" => "trash" }),
                  Icons::PackedSet.new(path: packed, aliases: { "trash-2": :trash })]

          sets.each do |set|
            assert_equal set.fetch(:trash), set.fetch(:"trash-2")
            assert_includes set, "trash-2"
            assert_equal [:trash], set.names, "aliases are not names"
            assert_equal({ "trash-2" => "trash" }, set.aliases)
          end
        end
      end

      def test_vendor_keeps_only_safe_inner_markup
        svg = <<~SVG
          <!-- a comment -->
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
            <title>Name</title><script>alert(1)</script>
            <path onclick="steal()" d="M0 0"/>
            <use href="https://evil.example/x.svg#a"/><use href="#local"/>
            <foreignObject><div>x</div></foreignObject>
          </svg>
        SVG

        assert_equal %(<path d="M0 0"/><use href="#local"/>), Icons::Vendor.inner_markup(svg)
      end

      def test_vendor_repaints_hardcoded_colours_and_drops_clips_that_clip_nothing
        svg = <<~SVG
          <svg viewBox="0 0 24 24" fill="none">
            <g clip-path="url(#c)"><path d="M1" stroke="#141B34" fill="black"/><path d="M2" fill="none"/></g>
            <defs><clipPath id="c"><rect width="24" height="24" fill="white"/></clipPath></defs>
          </svg>
        SVG

        assert_equal %(<path d="M1" stroke="currentColor" fill="currentColor"/><path d="M2" fill="none"/>),
                     Icons::Vendor.inner_markup(svg, current_color: true)
      end

      def test_vendor_refuses_names_a_set_cannot_serve
        assert_raises(ArgumentError) { Icons::Vendor.packed("c++" => "<path/>") }
        assert_raises(ArgumentError) { Icons::Vendor.packed("ok" => "<path/>\n<path/>") }
      end

      def test_fetch_rejects_malformed_names_with_the_same_error_class
        Dir.mktmpdir("icons") do |dir|
          set = Icons::FileSet.new(dir: dir)

          error = assert_raises(IconNotFound) { set.fetch("../secrets") }

          assert_includes error.message, "invalid icon name"
          assert_equal "../secrets", error.name
        end
      end
    end
  end
end
