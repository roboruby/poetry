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

            # The Menubar::Menu shape one fact further: the builder
            # declares which of its own setters a call cannot omit.
            REQUIRED_SLOTS = { handle: "the grip" }.freeze

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

            # The Toast shape: a lambda purely forwarding to one
            # component hides it - SLOT_RENDERS restores the fact.
            renders_one :pane, ->(**options, &block) { Glyph.new(**options, &block) }

            SLOT_BUILDERS = { row: Tray }.freeze
            SLOT_REQUIRED_CONTENT = { slide: "the slide" }.freeze
            SLOT_BLOCK_YIELDS = { cell: "the row record" }.freeze
            SLOT_RENDERS = { pane: Glyph }.freeze
            # Keyed by setter: a renders_one name and a polymorphic type
            # both resolve.
            REQUIRED_SLOTS = { icon: "the leading glyph", row: "at least one row" }.freeze
            # The Button/Command shape: the before_render
            # disjunction, one group per contract.
            REQUIRES_ANY = [
              { hint: "nothing visible renders without one",
                content: true, slots: %w[icon], options: %w[label] }
            ].freeze

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

        def test_required_styles_carry_the_flag_through_the_projection
          klass = Class.new(Poetry::Core::Component) do
            style :tone, default: :gray, required: true, variants: %i[gray red]
            style :size, default: :small, required: true, variants: %i[small large]
          end
          styles = klass.prop_definitions[:styles]

          assert_equal %i[size tone], styles.map { |s| s[:name] }.sort
          assert(styles.all? { |s| s[:required] })
        end

        # --- REQUIRED_SLOTS (the menu crash class - required slots the contract kept silent) ---

        def test_declared_required_slots_are_validated_and_carried
          assert_equal({ "icon" => "the leading glyph", "row" => "at least one row" },
                       props[:required_slots])
        end

        def test_builder_surfaces_carry_their_own_required_slots
          surface = props[:slots].find { |slot| slot[:name] == :entries }[:builders].fetch(:row)

          assert_equal({ "handle" => "the grip" }, surface[:required_slots])
        end

        def test_an_unresolvable_required_slots_key_fails_loudly
          orphan = Class.new(Poetry::Core::Component) do
            renders_one :icon
            const_set(:REQUIRED_SLOTS, { titel: "a typo" }.freeze)
          end

          error = assert_raises(Poetry::Core::Error) do
            Introspection.required_slots_surface(orphan, Introspection.slot_surface(orphan))
          end
          assert_includes error.message, ":titel"
          assert_includes error.message, "matches no slot setter"
        end

        # --- REQUIRES_ANY + SLOT_RENDERS (the any-of crash classes) ---

        def test_declared_requires_any_is_validated_and_carried
          assert_equal [{ "hint" => "nothing visible renders without one",
                          "content" => true, "slots" => ["icon"], "options" => ["label"] }],
                       props[:requires_any]
        end

        def test_a_requires_any_group_without_alternatives_fails_loudly
          hollow = Class.new(Poetry::Core::Component) do
            const_set(:REQUIRES_ANY, [{ hint: "nothing satisfiable" }].freeze)
          end

          error = assert_raises(Poetry::Core::Error) do
            Introspection.requires_any_surface(hollow, Introspection.slot_surface(hollow))
          end
          assert_includes error.message, "at least one alternative"
        end

        def test_a_requires_any_slot_alternative_must_resolve
          orphan = Class.new(Poetry::Core::Component) do
            renders_one :icon
            const_set(:REQUIRES_ANY, [{ hint: "x", slots: %w[nonexistent] }].freeze)
          end

          error = assert_raises(Poetry::Core::Error) do
            Introspection.requires_any_surface(orphan, Introspection.slot_surface(orphan))
          end
          assert_includes error.message, "matches no slot setter"
        end

        def test_slot_renders_restores_the_component_fact_a_lambda_hides
          pane = props[:slots].find { |slot| slot[:name] == :pane }

          assert_equal Probe::Glyph.component_path, pane[:component],
                       "the declared class projects its component_path"
        end

        def test_slot_renders_must_name_a_component_class
          liar = Class.new(Poetry::Core::Component) do
            renders_one :pane, ->(**options) { options }
            const_set(:SLOT_RENDERS, { pane: String }.freeze)
          end

          error = assert_raises(Poetry::Core::Error) { Introspection.slot_surface(liar) }
          assert_includes error.message, "must be a poetry component class"
        end

        # A component declaring every slot shape through the keyword
        # surface: doc: alone, doc: + renders:, doc: + types:, and doc:
        # alongside a positional class renderable.
        module KeywordProbe
          class Component < Poetry::Core::Component
            renders_one :leading, doc: "Optional leading visual."
            renders_many :lines,
                         doc: "The lines, in call order.",
                         renders: ->(label:) { { label: label } }
            renders_many :entries,
                         doc: "The entry union: row or divider.",
                         types: {
                           row: { renders: ->(**) { "row" }, as: :row },
                           divider: { renders: ->(**) { "divider" }, as: :divider }
                         }
            renders_one :badge, Probe::Glyph, doc: "The status glyph."

            def call
              content_tag(:span, "probe")
            end
          end
        end

        def keyword_slots
          KeywordProbe::Component.prop_definitions[:slots]
        end

        def test_the_doc_keyword_lands_in_the_slot_docs_map
          assert_equal "Optional leading visual.", KeywordProbe::Component.slot_docs[:leading]
        end

        def test_the_doc_keyword_travels_to_the_slot_definition_description
          leading = keyword_slots.find { |slot| slot[:name] == :leading }

          assert_equal "Optional leading visual.", leading[:description]
        end

        def test_the_renders_keyword_passes_the_callable_and_keys_the_doc_by_plural_name
          lines = keyword_slots.find { |slot| slot[:name] == :lines }

          assert lines[:many]
          assert_equal "The lines, in call order.", lines[:description]
          assert_equal({ line: ["label"] }, lines[:setter_kwargs],
                       "the keyword-passed lambda reaches ViewComponent and introspects")
        end

        def test_the_types_keyword_still_registers_the_polymorphic_slot
          entries = keyword_slots.find { |slot| slot[:name] == :entries }

          assert_equal %i[row divider], entries[:types]
          assert_equal "The entry union: row or divider.", entries[:description]
        end

        def test_a_positional_renderable_composes_with_the_doc_keyword
          badge = keyword_slots.find { |slot| slot[:name] == :badge }

          assert_equal Probe::Glyph.component_path, badge[:component]
          assert_equal "The status glyph.", badge[:description]
        end

        def test_an_unknown_slot_keyword_fails_at_class_load
          error = assert_raises(Poetry::Core::Error) do
            Class.new(Poetry::Core::Component) do
              renders_one :header, docs: "a typo of doc:"
            end
          end

          assert_includes error.message, "unknown slot option"
        end

        def test_a_positional_callable_cannot_be_combined_with_renders
          error = assert_raises(Poetry::Core::Error) do
            Class.new(Poetry::Core::Component) do
              renders_one :header, ->(**options) { options }, renders: ->(**options) { options }
            end
          end

          assert_includes error.message, "not both"
        end
      end
    end
  end
end
