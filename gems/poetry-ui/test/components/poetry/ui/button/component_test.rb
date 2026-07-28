# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Button
      class ComponentTest < ViewComponent::TestCase
        def render_button(text = "Save", **, &block)
          render_inline(Component.new(**), &block || proc { text }).to_html
        end

        # -- The contract root ------------------------------------------------

        def test_default_render_carries_the_full_self_identification_contract
          html = render_button

          assert_includes html, 'data-component="button"'
          assert_includes html, 'data-slot="button"'
          assert_includes html, 'data-variant="default"'
          assert_includes html, 'data-size="default"'
          assert_includes html, 'type="button"'
          # The design rides the theme layer (N11): the block class plus the
          # variant name are the markup-level contract; themes/default.css
          # carries bg-primary / the focus-visible ring under these names.
          assert_includes html, "cn-button "
          assert_includes html, "cn-button-variant-default"
          assert_includes html, %(<span data-slot="label" class="contents">Save</span>)
        end

        def test_mixed_content_stays_flex_aligned
          # The docs-search regression: an icon passed IN the content (not
          # the leading slot) must become a flex item of the button, not
          # inline flow inside the label span - preflight makes svg
          # display:block, which would force a line break there. The
          # contents class flattens the span so items-center/gap apply.
          html = render_inline(Component.new(variant: :outline)) do
            %(<svg class="size-3.5"></svg><span>Search docs</span><kbd>K</kbd>).html_safe
          end.to_html

          assert_includes html, %(<span data-slot="label" class="contents">)
        end

        def test_a_button_with_nothing_visible_refuses_to_render
          # label: is the accessible name, not visible text - silently
          # rendering a blank square is the agent footgun the 2026-07-01
          # browser pass caught.
          error = assert_raises(ArgumentError) { render_inline(Component.new(label: "Primary")) }

          assert_match(/renders nothing visible/, error.message)
        end

        def test_loading_alone_is_visible_enough
          html = render_inline(Component.new(loading: true, label: "Saving")).to_html

          assert_includes html, 'data-slot="spinner"'
        end

        def test_variant_and_size_classes_resolve_through_the_dictionary
          html = render_button(variant: :destructive, size: :lg)

          # The names ARE the resolution proof; the composited dark
          # destructive treatment the contrast gate models (dark:bg-destructive/60)
          # lives in the theme rule .cn-button-variant-destructive.
          assert_includes html, "cn-button-variant-destructive"
          assert_includes html, "cn-button-size-lg"
        end

        # The variant_smoke bar from the plan: every variant x size renders.
        def test_every_variant_by_size_combination_renders
          Component::VARIANTS.each do |variant|
            Component::SIZES.each do |size|
              options = { variant: variant, size: size }
              options[:label] = "Act" if size.to_s.start_with?("icon")
              html = render_inline(Component.new(**options)) { "Act" }.to_html

              assert_includes html, %(data-variant="#{variant}"), "#{variant}/#{size} must render"
              assert_includes html, %(data-size="#{size}")
            end
          end
        end

        def test_caller_classes_win_tailwind_conflicts
          html = render_button(class: "bg-accent")

          assert_match(/[" ]bg-accent[" ]/, html)
          # The exact token is replaced; hover:bg-primary/90 legitimately stays.
          refute_match(/[" ]bg-primary[" ]/, html)
        end

        # -- Accessibility ----------------------------------------------------

        def test_icon_only_requires_an_accessible_name
          error = assert_raises(ArgumentError) { Component.new(size: :icon) }

          assert_match(/label/, error.message)
        end

        def test_icon_only_renders_aria_label_and_no_label_span
          html = render_inline(Component.new(size: :icon, label: "Add item")) do |_c|
            %(<svg viewBox="0 0 24 24"></svg>).html_safe
          end.to_html

          assert_includes html, 'aria-label="Add item"'
          refute_includes html, 'data-slot="label"'
        end

        def test_disabled_native_button_uses_the_real_attribute
          html = render_button(disabled: true)

          assert_includes html, "disabled"
          refute_includes html, "aria-disabled"
        end

        # -- Loading (zero-JS baseline) ----------------------------------------

        def test_loading_renders_busy_disabled_spinner_and_sr_text
          html = render_button(loading: true)

          assert_includes html, 'aria-busy="true"'
          assert_includes html, "disabled"
          assert_includes html, 'data-loading="true"'
          assert_includes html, 'data-slot="spinner"'
          assert_includes html, "animate-spin"
          assert_includes html, %(<span class="sr-only">Loading…</span>)
        end

        # -- Polymorphic root (tag: :a) ----------------------------------------

        def test_link_tag_renders_an_anchor_with_button_role
          html = render_button(tag: :a, href: "/pricing", variant: :link)

          assert_includes html, "<a "
          assert_includes html, 'role="button"'
          assert_includes html, 'href="/pricing"'
          refute_includes html, "type="
        end

        def test_disabled_link_is_faux_disabled_without_href
          html = render_button(tag: :a, href: "/pricing", disabled: true)

          assert_includes html, 'aria-disabled="true"'
          refute_includes html, "href="
        end

        def test_href_alone_implies_the_anchor
          # The Badge/menu-item convention: an href on a native <button>
          # would be silently dropped (the docs landing page shipped that
          # dead button), so href: switches the tag by itself.
          html = render_button(href: "/pricing")

          assert_includes html, "<a "
          assert_includes html, 'href="/pricing"'
          refute_includes html, "type="
        end

        # -- Slots -------------------------------------------------------------

        def test_leading_and_trailing_icon_slots_render_decoratively
          html = render_inline(Component.new) do |component|
            component.with_leading { %(<svg id="lead"></svg>).html_safe }
            component.with_trailing { %(<svg id="trail"></svg>).html_safe }
            "Next"
          end.to_html

          assert_match(/<span data-slot="icon" aria-hidden="true"><svg id="lead">/, html)
          assert_match(/<span data-slot="icon" aria-hidden="true"><svg id="trail">/, html)
        end

        # -- Validation + introspection -----------------------------------------

        def test_unknown_variant_and_type_are_invalid
          refute_predicate Component.new(variant: :sparkly), :valid?
          refute_predicate Component.new(type: :reset), :invalid?
          refute_predicate Component.new(type: :detonate), :valid?
        end

        def test_prop_definitions_expose_the_contract_surface
          props = Component.prop_definitions
          variant = props[:styles].find { |style| style[:name] == :variant }

          assert_equal Component::VARIANTS, variant[:variants]
          assert_equal 8, props[:styles].find { |style| style[:name] == :size }[:variants].size
          assert_includes props[:options].map { |option| option[:name] }, :label
          assert_equal [{ name: :leading, many: false }, { name: :trailing, many: false }], props[:slots]
        end

        def test_bem_ir_emits_the_stable_contract
          bem = Component.new(variant: :destructive, size: :"icon-sm", label: "Del").bem

          assert_includes bem, "poetry-ui-button"
          assert_includes bem, "poetry-ui-button--variant-destructive"
          assert_includes bem, "poetry-ui-button--size-icon-sm"
        end
      end
    end
  end
end
