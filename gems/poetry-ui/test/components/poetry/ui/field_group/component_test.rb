# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module FieldGroup
      class ComponentTest < ViewComponent::TestCase
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def test_renders_the_container_scope_responsive_fields_key_on
          html = render_inline(Component.new) { "fields" }.to_html
          root = doc(html).at_css("[data-slot=field-group]")

          assert_includes root["class"], "cn-field-group"
          # The named @container pair is the contract: responsive fields'
          # @md/field-group: placement queries measure against THIS scope.
          assert_includes root["class"], "@container/field-group"
          assert_includes root["class"], "group/field-group"
          refute_includes root["class"], "cn-field-group-choices"
          assert_includes html, "fields"
        end

        def test_choices_variant_emits_its_marker
          root = doc(render_inline(Component.new(variant: :choices)) { "rows" }.to_html)
                 .at_css("[data-slot=field-group]")

          # The tighter checkbox-run rhythm keys on the marker class
          # (upstream overrides data-slot to checkbox-group; poetry keeps
          # the slot stable - the drawer-direction marker pattern).
          assert_includes root["class"], "cn-field-group-choices"
        end

        def test_unknown_variant_is_invalid
          # The Button precedent: style axes validate through ActiveModel,
          # not a render-time KeyError.
          refute_predicate Component.new(variant: :tight), :valid?
          assert_predicate Component.new(variant: :choices), :valid?
        end
      end
    end
  end
end
