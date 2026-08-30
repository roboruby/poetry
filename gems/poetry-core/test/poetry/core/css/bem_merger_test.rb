# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module CSS
      class BemMergerTest < ViewComponent::TestCase
        def setup
          @merger = BemMerger.new
        end

        def test_dedupes_tokens_across_inputs_preserving_order
          assert_equal "pill pill--variant-danger custom",
                       @merger.merge("pill pill--variant-danger", "pill", :custom)
        end

        def test_applies_no_tailwind_semantics
          assert_equal "p-4 p-2 text-red-500 text-blue-500",
                       @merger.merge("p-4 p-2", "text-red-500 text-blue-500")
        end

        def test_filters_blanks_and_returns_nil_for_empty
          assert_nil @merger.merge(nil, "", [])
          assert_equal "a b", @merger.merge(["a", nil], "", "b")
        end

        def test_the_classnames_seam_uses_the_configured_merger
          original = Poetry::Core::Config.current.classname_merger
          Poetry::Core::Config.current.classname_merger = BemMerger.new
          html = render_inline(Poetry::Core::Box::Component.new(html_tag: "span",
                                                                class: "custom custom p-4 p-2")) { "x" }

          assert_equal "custom p-4 p-2", html.css("span").first["class"]
        ensure
          Poetry::Core::Config.current.classname_merger = original
        end
      end
    end
  end
end
