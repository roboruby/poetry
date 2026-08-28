# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Combobox
      class ComponentTest < ViewComponent::TestCase
        # The class strings carry ">" ([&_svg...] selectors) - attribute
        # assertions go through Nokogiri, never [^>]* regexes across
        # class attributes (the Accordion test hazard).
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_combobox(**, &block)
          block ||= lambda { |combobox|
            combobox.with_item(value: "next.js") { "Next.js" }
            combobox.with_item(value: "sveltekit") { "SvelteKit" }
          }
          defaults = { "aria-label": "Framework", placeholder: "Select framework..." }
          render_inline(Component.new(**defaults, **), &block).to_html
        end

        def test_root_hosts_both_controllers_on_one_attributes_instance
          html = render_combobox
          root = doc(html).css('[data-slot="combobox"]').first

          assert_equal "combobox", root["data-component"]
          # ONE shared Attributes instance: token-concatenated, not overwritten.
          assert_equal "poetry--core--combobox poetry--core--popper", root["data-controller"]
          assert_equal "false", root["data-poetry--core--combobox-open-value"]
          assert_equal "", root["data-poetry--core--combobox-value-value"]
          assert_equal "false", root["data-poetry--core--combobox-modal-value"],
                       "modal defaults FALSE - Popover semantics (the delta vs Select's modal: true)"
          assert_equal "bottom", root["data-poetry--core--popper-side-value"]
          assert_equal "start", root["data-poetry--core--popper-align-value"]
          assert_equal "4", root["data-poetry--core--popper-side-offset-value"]
          assert_equal "true", root["data-poetry--core--popper-avoid-collisions-value"]
        end

        def test_the_shell_and_embedded_command_slots_all_render
          fragment = doc(render_combobox)

          %w[combobox combobox-trigger combobox-value combobox-native combobox-content
             combobox-item-indicator command command-input-wrapper command-input command-list
             command-empty command-item command-item-text command-status].each do |slot|
            assert_predicate fragment.css(%([data-slot="#{slot}"])), :any?, "missing data-slot #{slot}"
          end
        end

        def test_trigger_is_an_aria_wired_combobox_button_over_the_listbox
          html = render_combobox
          fragment = doc(html)
          trigger = fragment.css('button[data-slot="combobox-trigger"]').first
          list = fragment.css('[data-slot="command-list"]').first
          input = fragment.css('[data-slot="command-input"]').first

          assert_equal "combobox", trigger["role"]
          assert_equal "button", trigger["type"], "never an implicit submit"
          assert_equal "false", trigger["aria-expanded"]
          assert_equal "listbox", trigger["aria-haspopup"]
          # aria-controls -> the LISTBOX id (the controller resolves the
          # popup through it), asserted equal to the input's own target.
          assert_equal "listbox", list["role"]
          assert_equal list["id"], trigger["aria-controls"]
          assert_equal list["id"], input["aria-controls"],
                       "the double-combobox: both roles control the SAME listbox"
          assert_nil trigger["aria-autocomplete"], "the typing session belongs to the popup input"
          refute trigger.key?("data-popup-open"), "closed trigger carries NO state attribute (absence IS the state)"
          assert_equal "Framework", trigger["aria-label"]
          assert_equal "anchor", trigger["data-poetry--core--popper-target"]
          assert_includes trigger["data-action"], "click->poetry--core--combobox#toggle"
          assert_includes trigger["data-action"], "keydown->poetry--core--combobox#triggerKeydown"
          assert trigger.key?("data-placeholder"), "empty value dims the display (data-[placeholder])"
        end

        def test_trigger_wears_the_button_outline_chrome_with_the_double_chevron
          trigger = doc(render_combobox).css('[data-slot="combobox-trigger"]').first

          # The outline chrome (border/bg/shadow/hover, the demo width and
          # font-normal, the placeholder dim) rides .cn-combobox-trigger.
          %w[cn-combobox-trigger justify-between].each do |token|
            assert_includes trigger["class"].split, token
          end
          chevron = trigger.css("svg").first

          assert chevron, "the trailing ChevronsUpDown ships built in"
          assert_equal "true", chevron["aria-hidden"]
          assert_includes chevron["class"], "opacity-50"
        end

        def test_width_knob_replaces_the_demo_width_on_trigger_only
          trigger = doc(render_combobox(width: "w-80")).css('[data-slot="combobox-trigger"]').first

          assert_includes trigger["class"].split, "w-80"
          refute_includes trigger["class"].split, "w-[200px]", "the merger resolves the width conflict"
          content = doc(render_combobox(width: "w-80")).css('[data-slot="combobox-content"]').first

          assert_includes content["class"], "w-(--anchor-width)",
                          "the popup ALWAYS tracks the trigger (one knob, two surfaces)"
        end

        def test_value_display_shows_the_placeholder_then_the_selected_label
          placeholder_value = doc(render_combobox).css('[data-slot="combobox-value"]').first

          assert_equal "Select framework...", placeholder_value.text
          assert_equal "Select framework...", placeholder_value["data-placeholder"],
                       "the span carries the placeholder so the controller can restore it"
          assert_includes placeholder_value["class"], "truncate"

          html = render_combobox(value: "sveltekit")
          fragment = doc(html)
          display = fragment.css('[data-slot="combobox-value"]').first

          assert_equal "SvelteKit", display.text, "the LABEL, never the raw value"
          refute fragment.css('[data-slot="combobox-trigger"]').first.key?("data-placeholder")
        end

        def test_native_select_is_the_server_rendered_serialization_truth
          html = render_combobox(name: "post[framework]", value: "sveltekit", required: true)
          native = doc(html).css('select[data-slot="combobox-native"]').first
          options = native.css("option")

          assert_equal "post[framework]", native["name"]
          assert_equal "true", native["aria-hidden"]
          assert_equal "-1", native["tabindex"]
          assert native.key?("required"), "native constraint validation rides the real select"
          assert_includes native["class"], "sr-only", "visually hidden, never display:none (autofill needs paint)"
          assert_equal "change->poetry--core--combobox#nativeChanged", native["data-action"]
          # The blank option rides the placeholder; the value's option is selected.
          assert_equal(["", "next.js", "sveltekit"], options.map { |option| option["value"] })
          assert_equal "Select framework...", options.first.text
          assert options.find { |option| option["value"] == "sveltekit" }.key?("selected")
          refute options.first.key?("selected")
        end

        def test_native_blank_option_is_selected_when_no_value
          native = doc(render_combobox).css('[data-slot="combobox-native"]').first
          options = native.css("option")

          assert options.first.key?("selected"), "the blank option holds the empty value pre-commit"
          assert(options[1..].none? { |option| option.key?("selected") })
        end

        def test_content_is_a_closed_roleless_popup_with_no_static_layer_controllers
          html = render_combobox
          content = doc(html).css('[data-slot="combobox-content"]').first

          assert_nil content["role"], "the popup container has no role - the listbox lives inside"
          assert_equal "-1", content["tabindex"]
          assert content.key?("data-closed"), "mounted-closed popup carries bare data-closed"
          refute content.key?("data-open")
          assert_equal "bottom", content["data-side"]
          assert_equal "start", content["data-align"]
          assert content.key?("hidden"), "closed content is hidden (truthful server render)"
          assert_equal "content", content["data-poetry--core--popper-target"]
          # focus-scope/dismissable are token-ACTIVATED by the combobox
          # controller on open (NEVER roving-focus) - never server-rendered.
          assert_nil content["data-controller"]
          assert_includes content["class"], "cn-combobox-content" # p-0 rides the theme rule
          assert_predicate content.css('[data-slot="command-list"]'), :any?,
                           "the listbox sits INSIDE the content (the controller's closest() resolution)"
        end

        def test_embedded_command_root_carries_its_own_engine_controller
          html = render_combobox(filter: false, loop: true)
          command = doc(html).css('[data-slot="command"]').first

          assert_equal "poetry--core--command", command["data-controller"]
          assert_equal "false", command["data-poetry--core--command-filter-value"],
                       "filter: forwards to the embedded engine (the async recipe seam)"
          assert_equal "true", command["data-poetry--core--command-loop-value"]
          assert_nil command["id"], "the engine root takes no id - the shell owns the id scheme"
        end

        def test_filter_input_is_the_command_contract_at_the_demo_scale
          html = render_combobox
          input = doc(html).css('input[data-slot="command-input"]').first

          assert_equal "text", input["type"]
          assert_equal "combobox", input["role"]
          assert_equal "true", input["aria-expanded"]
          assert_equal "list", input["aria-autocomplete"]
          assert_equal "off", input["autocomplete"]
          assert_equal "Filter options", input["aria-label"],
                       "the input's OWN name (t('poetry.combobox.filter_label')), distinct from the field label"
          assert_includes input["class"].split, "h-full", "the input fills its well; the well's height is the theme's"
          refute_includes input["class"].split, "h-9", "no classic retune inline - it would size every theme's well"
          refute_includes input["class"].split, "h-10", "the merger resolves Command's h-10"
          assert_includes input["data-action"], "input->poetry--core--command#filterInput"
          assert_includes input["data-action"], "keydown->poetry--core--command#keydown"
        end

        def test_search_placeholder_lands_on_the_input
          input = doc(render_combobox(search_placeholder: "Search framework...."))
                  .css('[data-slot="command-input"]').first

          assert_equal "Search framework....", input["placeholder"]
        end

        def test_items_are_command_items_wearing_the_twin_selected_write_and_the_indicator
          html = render_combobox(value: "sveltekit")
          nextjs, sveltekit = doc(html).css('[data-slot="command-item"]').to_a

          assert_equal "option", nextjs["role"]
          assert_nil nextjs["tabindex"], "options are NEVER focusable (activedescendant, not roving focus)"
          assert nextjs.key?("data-poetry-collection-item")
          assert_equal "next.js", nextjs["data-value"]
          assert_includes nextjs["data-action"], "click->poetry--core--command#activate"
          assert_includes nextjs["data-action"], "pointermove->poetry--core--command#pointerHighlight"
          # aria-selected and data-selected flip TOGETHER, never separately
          # (unselected = data-selected ABSENT - no data-unselected exists).
          assert_equal "false", nextjs["aria-selected"]
          refute nextjs.key?("data-selected")
          assert_equal "true", sveltekit["aria-selected"]
          assert sveltekit.key?("data-selected")
          assert_equal 1, doc(html).css('[data-slot="command-item"][aria-selected="true"]').size,
                       "exactly one option selected per non-nil value"

          doc(html).css('[data-slot="command-item"]').each do |item|
            indicator = item.css('[data-slot="combobox-item-indicator"]').first

            assert indicator, "every item ships the indicator (data-selected drives visibility)"
            assert_includes indicator["class"], "ms-auto", "trailing per the demo (logical for RTL)"
            assert_includes indicator["class"], "[:not([data-selected])>&]:hidden",
                            "visible iff data-selected present - the attribute-driven check"
            assert_equal "true", indicator.css("svg").first["aria-hidden"]
          end
          assert_equal "SvelteKit", sveltekit.css('[data-slot="command-item-text"]').first.text,
                       "item-text is the node whose textContent becomes the display on commit"
        end

        def test_server_seeds_the_highlight_on_the_selected_option
          html = render_combobox(value: "sveltekit")
          fragment = doc(html)
          highlighted = fragment.css("[data-highlighted]").first
          input = fragment.css('[data-slot="command-input"]').first

          assert_equal "sveltekit", highlighted["data-value"],
                       "the committed option takes the server-rendered highlight seat"
          assert_equal highlighted["id"], input["aria-activedescendant"],
                       "the twin-write: data-highlighted + activedescendant together"
        end

        def test_without_a_value_the_first_enabled_item_takes_the_highlight
          html = render_combobox do |combobox|
            combobox.with_item(value: "a", disabled: true) { "A" }
            combobox.with_item(value: "b") { "B" }
          end
          highlighted = doc(html).css("[data-highlighted]").first

          assert_equal "b", highlighted["data-value"], "disabled items never take the seat"
        end

        def test_item_options_disabled_text_value_keywords_and_filter_value
          html = render_combobox do |combobox|
            combobox.with_item(value: "up", text_value: "Move up", keywords: %w[raise lift],
                               filter_value: "move") { "↑" }
            combobox.with_item(value: "api", disabled: true) { "API" }
            combobox.with_item(value: "pinned", always_render: true) { "Pinned" }
          end
          icon_rich, disabled, pinned = doc(html).css('[data-slot="command-item"]').to_a

          assert_equal "Move up", icon_rich["data-text-value"]
          assert_equal "raise lift", icon_rich["data-keywords"]
          assert_equal "move", icon_rich["data-filter-value"]
          # divs have no native disabled: aria-disabled + data-disabled together.
          assert_equal "true", disabled["aria-disabled"]
          assert disabled.key?("data-disabled")
          assert pinned.key?("data-always-render")
        end

        def test_text_value_feeds_the_native_option_label_and_the_display
          html = render_combobox(value: "up") do |combobox|
            combobox.with_item(value: "up", text_value: "Move up") { "↑" }
          end
          fragment = doc(html)

          assert_equal "Move up", fragment.css('[data-slot="combobox-native"] option[value="up"]').first.text
          assert_equal "Move up", fragment.css('[data-slot="combobox-value"]').first.text
        end

        def test_groups_wire_their_heading_via_aria_labelledby
          html = render_combobox do |combobox|
            combobox.with_group(heading: "Frameworks") do |group|
              group.with_item(value: "rails") { "Rails" }
            end
            combobox.with_separator
            combobox.with_item(value: "other") { "Other" }
          end
          fragment = doc(html)
          group = fragment.css('[data-slot="command-group"]').first
          heading = group.css('[data-slot="command-group-heading"]').first
          separator = fragment.css('[data-slot="command-separator"]').first

          assert_equal "group", group["role"]
          assert_equal heading["id"], group["aria-labelledby"]
          assert_equal "Frameworks", heading.text
          # The popup's geometry is the combobox's own (the list carries
          # the inset, the group is unpadded and hookless, the label is
          # themed) - Command's slot names stay for the engine.
          assert_nil group["class"], "the combobox group wears no classes (the list carries the inset)"
          assert_includes heading["class"], "cn-combobox-label"
          refute_includes heading["class"], "cn-command-group-heading"
          # Decorative, never role=separator: inside role=listbox that role
          # is flagged (the select/command axe rule).
          assert_equal "true", separator["aria-hidden"]
          assert_nil separator["role"]
          # Grouped options still land in the shared native select, in DOM order.
          assert_equal(%w[rails other],
                       fragment.css('[data-slot="combobox-native"] option:not([value=""])').map { |o| o["value"] })
        end

        def test_empty_part_renders_hidden_with_the_i18n_default_and_the_slot_override
          fragment = doc(render_combobox)
          empty = fragment.css('[data-slot="command-empty"]').first

          assert empty.key?("hidden"), "the engine unhides it on zero matches"
          assert_equal "No results found.", empty.text

          html = render_combobox do |combobox|
            combobox.with_empty { "No framework found." }
            combobox.with_item(value: "a") { "A" }
          end

          assert_equal "No framework found.", doc(html).css('[data-slot="command-empty"]').first.text
        end

        def test_status_live_region_carries_the_localized_count_templates
          status = doc(render_combobox).css('[data-slot="command-status"]').first

          assert_equal "status", status["role"]
          assert_equal "polite", status["aria-live"]
          assert_equal "0 results", status["data-zero"]
          assert_equal "%{count} results", status["data-other"] # rubocop:disable Style/FormatStringToken
        end

        def test_stable_ids_derive_from_the_trigger_id
          html = render_combobox(id: "post-framework", "aria-describedby": "post-framework-error",
                                 "aria-invalid": "true")
          fragment = doc(html)
          trigger = fragment.css('[data-slot="combobox-trigger"]').first

          assert_equal "post-framework", trigger["id"], "label[for] must reach the combobox"
          assert_equal "post-framework-content", fragment.css('[data-slot="combobox-content"]').first["id"]
          assert_equal "post-framework-list", fragment.css('[data-slot="command-list"]').first["id"]
          assert_equal "post-framework-native", fragment.css('[data-slot="combobox-native"]').first["id"]
          assert_equal "post-framework-input", fragment.css('[data-slot="command-input"]').first["id"]
          assert_equal(%w[post-framework-item-0 post-framework-item-1],
                       fragment.css('[data-slot="command-item"]').map { |item| item["id"] })
          # Field control_attributes land on the TRIGGER, never the root.
          assert_equal "post-framework-error", trigger["aria-describedby"]
          assert_equal "true", trigger["aria-invalid"]
          root = fragment.css('[data-slot="combobox"]').first

          assert_nil root["aria-describedby"]
          assert_nil root["aria-invalid"]
        end

        def test_open_state_is_server_rendered
          html = render_combobox(open: true)
          content = doc(html).css('[data-slot="combobox-content"]').first
          trigger = doc(html).css('[data-slot="combobox-trigger"]').first

          assert content.key?("data-open"), "open popup carries bare data-open"
          refute content.key?("data-closed")
          refute content.key?("hidden")
          assert_equal "true", trigger["aria-expanded"]
          assert trigger.key?("data-popup-open"), "open trigger carries bare data-popup-open"
        end

        def test_disabled_disables_trigger_native_and_input_together
          fragment = doc(render_combobox(disabled: true))

          assert fragment.css('[data-slot="combobox-trigger"]').first.key?("disabled")
          assert fragment.css('[data-slot="combobox-native"]').first.key?("disabled")
          assert fragment.css('[data-slot="command-input"]').first.key?("disabled")
        end

        def test_rtl_sets_dir_on_the_root
          root = doc(render_combobox(dir: :rtl)).css('[data-slot="combobox"]').first

          assert_equal "rtl", root["dir"]
        end

        def test_unknown_value_falls_back_to_the_placeholder_display
          html = render_combobox(value: "ember")
          fragment = doc(html)

          assert_equal "Select framework...", fragment.css('[data-slot="combobox-value"]').first.text
          assert fragment.css('[data-slot="combobox-trigger"]').first.key?("data-placeholder")
          assert_empty fragment.css('[data-slot="command-item"][aria-selected="true"]')
        end

        def test_duplicate_option_values_raise
          error = assert_raises(ArgumentError) do
            render_combobox do |combobox|
              combobox.with_item(value: "next.js") { "Next.js" }
              combobox.with_group(heading: "More") { |group| group.with_item(value: "next.js") { "Again" } }
            end
          end

          assert_includes error.message, "duplicate Combobox option value"
        end

        def test_blank_item_value_raises
          assert_raises(ArgumentError) do
            render_combobox { |combobox| combobox.with_item(value: "") { "Empty" } }
          end
        end

        def test_multiple_makes_value_list_capable
          component = Component.new(multiple: true, value: %w[b a b], "aria-label": "Framework")

          assert_predicate component, :multiple
          assert_equal %w[b a], component.selected_values, "stringified, deduped, value order preserved"
          assert_equal %w[b a], component.selected_value,
                       "downstream selection tests flip to array inclusion"

          scalar = Component.new(multiple: true, value: "solo", "aria-label": "Framework")

          assert_equal %w[solo], scalar.selected_values, "a scalar adopts as a one-element list (List-cast)"
        end

        def test_a_nameless_bare_combobox_fails_the_render
          error = assert_raises(ArgumentError) do
            render_inline(Component.new(placeholder: "Pick")) do |combobox|
              combobox.with_item(value: "a") { "A" }
            end
          end

          assert_includes error.message, "accessible name"
        end

        def test_an_explicit_id_counts_as_field_label_pairable
          html = render_inline(Component.new(id: "prefs-framework", placeholder: "Pick")) do |combobox|
            combobox.with_item(value: "a") { "A" }
          end.to_html

          assert_includes html, 'id="prefs-framework"'
        end

        def test_required_slot_guards
          assert_raises(ArgumentError, "missing items") do
            render_inline(Component.new("aria-label": "Framework"))
          end
          assert_raises(ArgumentError, "empty group") do
            render_inline(Component.new("aria-label": "Framework")) do |combobox|
              combobox.with_group(heading: "G")
            end
          end
          assert_raises(ArgumentError, "heading required") do
            render_inline(Component.new("aria-label": "Framework")) do |combobox|
              combobox.with_group(heading: "") { |group| group.with_item(value: "a") { "A" } }
            end
          end
        end

        def test_source_exact_classes_land_on_the_parts
          html = render_combobox

          assert_includes html, "w-(--anchor-width)"
          assert_includes html, "origin-(--transform-origin)"
          # The placeholder dim + the animate chain ride the theme rules.
          assert_includes html, "cn-combobox-trigger"
          assert_includes html, "cn-combobox-content"
        end

        def test_a_custom_trigger_icon_groups_with_the_value_display
          fragment = doc(render_combobox do |combobox|
            combobox.with_trigger { "<svg data-icon></svg>".html_safe }
            combobox.with_item(value: "next.js") { "Next.js" }
          end)
          trigger = fragment.css('[data-slot="combobox-trigger"]').first
          value = trigger.css('[data-slot="combobox-value"]').first
          group = value.parent

          assert_equal "span", group.name, "icon + value share a leading group under justify-between"
          assert_includes group["class"], "min-w-0", "truncate must keep working inside the flex group"
          assert_predicate group.css("svg[data-icon]"), :any?, "the slot content rides the same group"
          # the chevrons stay OUTSIDE the group - the row's other end
          assert_equal trigger, group.parent

          # slot-less triggers keep the flat two-child markup byte-identical
          plain = doc(render_combobox).css('[data-slot="combobox-value"]').first

          assert_equal "button", plain.parent.name
        end

        # -- show_clear (Base UI Combobox.Clear) ---------------------------------

        def test_show_clear_renders_the_x_as_the_triggers_immediate_sibling
          fragment = doc(render_combobox(show_clear: true, value: "next.js"))
          clear = fragment.css('button[data-slot="combobox-clear"]').first

          refute_nil clear
          assert_equal "button", clear["type"]
          assert_equal "Clear selection", clear["aria-label"]
          assert_includes clear["data-action"], "poetry--core--combobox#clear"
          refute clear.has_attribute?("hidden"), "a committed value shows the X"
          # The chevron-swap CSS keys on trigger + clear ADJACENCY.
          trigger = fragment.css('[data-slot="combobox-trigger"]').first

          assert_equal clear, trigger.next_element
          # The chevron keeps its box: the swap class rides the icon.
          assert_includes trigger.css("svg").last["class"], ":invisible"
        end

        def test_show_clear_starts_hidden_without_a_value_and_skips_the_swap_class_when_off
          fragment = doc(render_combobox(show_clear: true))

          assert fragment.css('[data-slot="combobox-clear"]').first.has_attribute?("hidden"),
                 "no value - the X starts hidden (the controller flips it on every commit)"

          plain = doc(render_combobox)

          assert_empty plain.css('[data-slot="combobox-clear"]')
          refute_includes plain.css('[data-slot="combobox-trigger"] svg').last["class"], ":invisible"
        end

        def test_show_clear_forces_the_blank_native_option_and_rides_disabled
          fragment = doc(render_combobox(show_clear: true, value: "next.js", placeholder: nil))
          blanks = fragment.css('[data-slot="combobox-native"] option[value=""]')

          assert_equal 1, blanks.length, "the cleared state must serialize as \"\""
          refute blanks.first.has_attribute?("selected"), "the committed value keeps its selection"

          disabled = doc(render_combobox(show_clear: true, value: "next.js", disabled: true))

          assert disabled.css('[data-slot="combobox-clear"]').first.has_attribute?("disabled")
        end

        def test_show_clear_is_single_mode_only
          error = assert_raises(ArgumentError) do
            render_combobox(show_clear: true, multiple: true, name: "stack")
          end

          assert_match(/single-mode only/, error.message)
        end
      end
    end
  end
end
