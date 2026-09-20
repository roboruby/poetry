# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Fieldset
      class ComponentTest < ViewComponent::TestCase
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def test_renders_a_real_fieldset_named_by_a_real_legend
          html = render_inline(Component.new(legend: "Address information")) { "fields" }.to_html
          root = doc(html).at_css("fieldset[data-slot=field-set]")

          assert root, "the group layer is a native <fieldset>, never a styled div"
          legend = root.at_css("legend[data-slot=field-legend]")

          assert_equal "Address information", legend.text
          assert_equal "legend", legend["data-variant"]
          assert_includes root["class"], "cn-field-set"
          assert_includes html, "fields"
        end

        def test_legend_variant_label_renders_the_label_sized_legend
          html = render_inline(Component.new(legend: "Show these items",
                                             legend_variant: :label)) { "rows" }.to_html
          legend = doc(html).at_css("legend[data-slot=field-legend]")

          # Upstream's FieldLabel-in-FieldSet form, folded into the legend
          # so the group keeps its accessible name.
          assert_equal "label", legend["data-variant"]
        end

        def test_hint_renders_the_description_under_the_legend
          html = render_inline(Component.new(legend: "Address information",
                                             hint: "We deliver here.")) { "fields" }.to_html
          hint = doc(html).at_css("[data-slot=field-set-hint]")

          assert_equal "We deliver here.", hint.text
          assert_includes hint["class"], "cn-field-description"
          # Legend then hint - the theme's adjacency rule
          # ([data-variant=legend]+description) keys on this order.
          slots = doc(html).css("[data-slot]").map { |el| el["data-slot"] }

          assert_equal %w[field-set field-legend field-set-hint], slots
        end

        def test_legend_is_required
          assert_raises(ArgumentError) { render_inline(Component.new(legend: "")) { "x" } }
        end
      end
    end
  end
end
