# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Concerns
      class IntrospectionTest < Minitest::Test
        # A component exercising every prop-definition shape: static, proc,
        # and absent defaults; required; booleans; options; formats; both
        # slot kinds, typed and untyped.
        module Probe
          class Glyph < Poetry::Core::Component
            option :name, :symbol, required: true, format: :"icon-name"

            def call
              content_tag(:span, "glyph")
            end
          end

          # A plain ViewComponent builder (the Menubar::Menu shape): its own
          # slot surface + a hand-rolled convenience, reachable only through
          # a SLOT_BUILDERS declaration.
          class Tray < ViewComponent::Base
            renders_one :handle, ->(**options, &block) { { options: options, block: block } }

            def with_grip(text)
              with_handle { text }
            end

            def call
              content_tag(:span, "tray")
            end
          end

          class Component < Poetry::Core::Component
            style :color, default: :gray, required: true, variants: %i[gray red]
            style :dot_color, default: -> { color }, variants: %i[gray red]
            style :outlined, variants: :boolean, default: false
            option :label, :string
            option :count, :integer, default: 3

            renders_one :icon
            renders_many :items
            renders_one :badge, Glyph
            # House style: every polymorphic type declares as: matching its
            # key, so the registry's type list IS the setter list (any
            # divergence falls into slot_extras and stays valid anyway).
            renders_many :entries, types: {
              row: { renders: ->(**) { "row" }, as: :row },
              divider: { renders: ->(**) { "divider" }, as: :divider }
            }
            renders_many :chips, ->(text, tone: :gray) { { text: text, tone: tone } }
            renders_one :footer, ->(*parts) { parts }
            # The Carousel shape: a closed keyword signature that
            # consumes its block as content and cannot render without one.
            renders_many :slides, lambda { |classes: nil, &block|
              { classes: classes, block: block }
            }
            # The DataTable shape: the block is a renderer called WITH
            # arguments later - declared as yielding, so not yieldless.
            renders_many :cells, ->(label, &renderer) { { label: label, renderer: renderer } }

            SLOT_BUILDERS = { row: Tray }.freeze
            SLOT_REQUIRED_CONTENT = { slide: "the slide" }.freeze
            SLOT_BLOCK_YIELDS = { cell: "the row record" }.freeze

            # A hand-rolled convenience beyond the registered slots - part
            # of the consumer call surface (the NavigationMenu#with_link
            # shape).
            def with_shortcut(text)
              with_row { text }
            end

            def call
              content_tag(:span, "probe")
            end
          end
        end

        def props
          Probe::Component.prop_definitions
        end

        def test_style_definitions_carry_variants_defaults_and_required
          color = props[:styles].find { |style| style[:name] == :color }

          assert_equal :symbol, color[:type]
          assert_equal %i[gray red], color[:variants]
          assert_equal :gray, color[:default]
          assert color[:required]
        end

        def test_proc_defaults_are_marked_dynamic_not_evaluated
          dot = props[:styles].find { |style| style[:name] == :dot_color }

          assert_equal Introspection::DYNAMIC_DEFAULT, dot[:default]
        end

        def test_boolean_styles_report_boolean_type_and_false_default
          outlined = props[:styles].find { |style| style[:name] == :outlined }

          assert_equal :boolean, outlined[:type]
          # rubocop:disable Minitest/RefuteFalse -- refute would also pass for nil; this pins the literal false
          assert_equal false, outlined[:default], "a false default must not be dropped"
          # rubocop:enable Minitest/RefuteFalse
          refute outlined.key?(:variants), ":boolean is a type, not a variant list"
        end

        def test_option_definitions_carry_type_and_default_presence
          label = props[:options].find { |option| option[:name] == :label }
          count = props[:options].find { |option| option[:name] == :count }

          assert_equal :string, label[:type]
          refute label.key?(:default), "no default declared means no default key"
          assert_equal 3, count[:default]
        end

        def test_slot_definitions_distinguish_one_from_many
          slots = props[:slots]

          assert_includes slots, { name: :icon, many: false }
          assert_includes slots, { name: :items, many: true }
        end

        def test_a_declared_format_is_carried_and_absence_stays_absent
          name = Probe::Glyph.prop_definitions[:options].find { |option| option[:name] == :name }
          label = props[:options].find { |option| option[:name] == :label }

          assert_equal :"icon-name", name[:format]
          refute label.key?(:format), "no format declared means no format key"
        end

        def test_a_typed_slot_carries_its_component_path
          badge = props[:slots].find { |slot| slot[:name] == :badge }
          icon = props[:slots].find { |slot| slot[:name] == :icon }

          assert_equal Probe::Glyph.component_path, badge[:component]
          refute icon.key?(:component), "an untyped slot has no component to point at"
        end

        def test_a_polymorphic_slot_carries_its_type_setters
          entries = props[:slots].find { |slot| slot[:name] == :entries }
          icon = props[:slots].find { |slot| slot[:name] == :icon }

          assert_equal %i[row divider], entries[:types]
          refute icon.key?(:types), "a plain slot has no types"
        end

        def test_hand_rolled_with_conveniences_surface_as_slot_extras
          assert_equal ["shortcut"], props[:slot_extras]
          assert_empty Probe::Glyph.prop_definitions[:slot_extras]
        end

        def test_setter_positional_arities_are_introspected_from_the_callables
          slots = props[:slots]
          entries = slots.find { |slot| slot[:name] == :entries }
          chips = slots.find { |slot| slot[:name] == :chips }
          footer = slots.find { |slot| slot[:name] == :footer }

          assert_equal({ row: 0, divider: 0 }, entries[:setter_args], "kwargs-only lambdas take zero positionals")
          assert_equal({ chip: 1 }, chips[:setter_args], "a required positional counts")
          refute footer.key?(:setter_args), "a *rest signature is unknowable - no arity claimed"
        end

        def test_closed_keyword_signatures_are_introspected_and_open_ones_stay_unclaimed
          slots = props[:slots]
          slides = slots.find { |slot| slot[:name] == :slides }

          assert_equal({ slide: ["classes"] }, slides[:setter_kwargs])
          refute slots.find { |slot| slot[:name] == :chips }.key?(:setter_kwargs),
                 "a positional parameter can swallow a braceless hash - no keyword contract"
          refute slots.find { |slot| slot[:name] == :entries }.key?(:setter_kwargs),
                 "**rest accepts anything - no keyword contract"
          refute slots.find { |slot| slot[:name] == :badge }.key?(:setter_kwargs),
                 "class renderables take kwargs through the attributes hash"
        end

        def test_block_consuming_lambdas_read_as_yieldless
          slots = props[:slots]

          assert_equal [:slide], slots.find { |slot| slot[:name] == :slides }[:yieldless]
          refute slots.find { |slot| slot[:name] == :badge }.key?(:yieldless),
                 "a class renderable yields the component instance to the block"
          refute slots.find { |slot| slot[:name] == :icon }.key?(:yieldless),
                 "a bare slot has no lambda to consume the block"
        end

        def test_a_declared_block_yields_setter_is_exempt_from_yieldless
          cells = props[:slots].find { |slot| slot[:name] == :cells }

          refute cells.key?(:yieldless),
                 "SLOT_BLOCK_YIELDS declares the block receives arguments - not yieldless"
        end

        def test_declared_required_content_is_carried_per_setter
          slots = props[:slots]

          assert_equal({ slide: "the slide" }, slots.find { |slot| slot[:name] == :slides }[:required_content])
          refute slots.find { |slot| slot[:name] == :chips }.key?(:required_content),
                 "no declaration means no requirement claimed"
        end

        def test_a_declared_builder_recurses_into_its_own_surface
          entries = props[:slots].find { |slot| slot[:name] == :entries }
          surface = entries[:builders].fetch(:row)

          assert_equal :handle, surface[:slots].first[:name]
          assert_equal({ handle: 0 }, surface[:slots].first[:setter_args])
          assert_equal ["grip"], surface[:slot_extras]
          refute entries[:builders].key?(:divider), "no builder declared means no surface"
        end

        def test_x_component_full_surface
          styles = Poetry::Core::X::Component.prop_definitions[:styles]

          assert_equal %i[color mode shape size], styles.map { |s| s[:name] }.sort
          assert(styles.all? { |s| s[:required] })
        end
      end
    end
  end
end
