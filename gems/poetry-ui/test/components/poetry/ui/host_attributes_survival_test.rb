# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The host-attributes survival sweep (the attribute-merge audit's
    # durable gate): every caller-facing surface the audit converted to
    # Attributes.merged renders here with a poisoned host data-action /
    # data-controller, and the assertion is that BOTH the host's token and
    # the component's own wiring survive into the parsed attribute.
    #
    # The parsed-attribute check catches both historical failure modes at
    # once: a clobber drops the wiring token, and a double-emitted
    # attribute is collapsed by the HTML parser to its FIRST occurrence
    # (exactly what browsers do), which drops the host token.
    #
    # Root-level survival for all components rides the one shared
    # merge_if_not_set path and is pinned by the accordion render test +
    # the Attributes unit matrix; this file enumerates the SLOT surfaces,
    # which were 30-odd separate hand-rolled merge sites.
    class HostAttributesSurvivalTest < ViewComponent::TestCase
      HOST_ACTION = "click->host#probe"
      HOST_CONTROLLER = "host-probe"

      def assert_survival(attribute_value, surface)
        assert attribute_value.to_s.include?("host#probe") || attribute_value.to_s.include?(HOST_CONTROLLER),
               "#{surface}: host token lost (got: #{attribute_value.inspect})"
        assert_includes attribute_value.to_s, "poetry--", "#{surface}: component wiring lost"
      end

      def test_dropdown_menu_item_keeps_wiring_under_host_action
        render_inline(DropdownMenu::Component.new) do |menu|
          menu.with_trigger { "Open" }
          menu.with_item(data: { action: HOST_ACTION }) { "Profile" }
        end

        assert_survival page.find("[data-slot=dropdown-menu-item]", visible: :all)["data-action"], "dropdown item"
      end

      def test_dropdown_menu_item_flat_spelling_survives_too
        render_inline(DropdownMenu::Component.new) do |menu|
          menu.with_trigger { "Open" }
          menu.with_item("data-action" => HOST_ACTION) { "Profile" }
        end

        assert_survival page.find("[data-slot=dropdown-menu-item]", visible: :all)["data-action"],
                        "dropdown item (flat)"
      end

      def test_context_menu_item_and_trigger_surface_keep_wiring
        render_inline(ContextMenu::Component.new) do |menu|
          menu.with_trigger(data: { action: HOST_ACTION }) { "Surface" }
          menu.with_item(data: { action: HOST_ACTION }) { "Rename" }
        end

        assert_survival page.find("[data-slot=context-menu-trigger]")["data-action"], "context trigger"
        assert_survival page.find("[data-slot=context-menu-item]", visible: :all)["data-action"], "context item"
      end

      def test_menubar_menu_wrapper_keeps_controller_registrations
        render_inline(Menubar::Component.new(label: "Main")) do |bar|
          bar.with_menu(data: { controller: HOST_CONTROLLER }) do |menu|
            menu.with_trigger { "File" }
            menu.with_item(data: { action: HOST_ACTION }) { "New Tab" }
          end
        end

        assert_survival page.find("[data-slot=menubar-menu]", visible: :all)["data-controller"], "menubar wrapper"
        assert_survival page.find("[data-slot=menubar-item]", visible: :all)["data-action"], "menubar item"
      end

      def test_command_item_keeps_wiring_and_the_server_stable_id
        render_inline(Command::Component.new("aria-label" => "Palette")) do |command|
          command.with_item(value: "calendar", data: { action: HOST_ACTION }) { "Calendar" }
        end

        item = page.find("[data-slot=command-item]", visible: :all)

        assert_survival item["data-action"], "command item"
        assert_predicate item["id"], :present?, "command item: the aria-activedescendant id contract broke"
      end

      def test_combobox_item_keeps_wiring
        render_inline(Combobox::Component.new("aria-label" => "Framework")) do |combobox|
          combobox.with_item(value: "next.js", data: { action: HOST_ACTION }) { "Next.js" }
        end

        assert_survival page.find("[data-slot=command-item]", visible: :all)["data-action"], "combobox item"
      end

      def test_select_item_keeps_wiring_and_data_value
        render_inline(Select::Component.new(name: "fruit", "aria-label" => "Fruit")) do |select|
          select.with_item(value: "apple", data: { action: HOST_ACTION }) { "Apple" }
        end

        item = page.find("[data-slot=select-item]", visible: :all)

        assert_survival item["data-action"], "select item"
        assert_equal "apple", item["data-value"], "select item: the native-select mirror value broke"
      end

      def test_radio_group_and_toggle_group_items_keep_wiring
        render_inline(RadioGroup::Component.new(name: "plan", label: "Plan")) do |group|
          group.with_item(value: "monthly", label: "Monthly", data: { action: HOST_ACTION })
        end

        assert_survival page.find("[data-slot=radio-group-item]", visible: :all)["data-action"], "radio item"

        render_inline(ToggleGroup::Component.new(label: "Formatting")) do |group|
          group.with_item(value: "bold", label: "Toggle bold", data: { action: HOST_ACTION }) { "B" }
        end

        assert_survival page.find("[data-slot=toggle-group-item]", visible: :all)["data-action"], "toggle item"
      end

      def test_collapsible_and_hover_card_triggers_keep_wiring
        render_inline(Collapsible::Component.new) do |collapsible|
          collapsible.with_trigger(data: { action: HOST_ACTION }) { "Show" }
        end

        assert_survival page.find("[data-slot=collapsible-trigger]", visible: :all)["data-action"],
                        "collapsible trigger"

        render_inline(HoverCard::Component.new) do |card|
          card.with_trigger(href: "https://example.test", data: { action: HOST_ACTION }) { "@nextjs" }
        end

        assert_survival page.find("[data-slot=hover-card-trigger]", visible: :all)["data-action"], "hover card trigger"
      end

      def test_dialog_and_alert_dialog_slots_keep_wiring
        render_inline(Dialog::Component.new.tap do |dialog|
          dialog.with_trigger(data: { action: HOST_ACTION }) { "Open" }
          dialog.with_title { "Title" }
        end.with_content("Body"))

        assert_survival page.find("button[data-action*='#open']", visible: :all)["data-action"], "dialog trigger"

        render_inline(AlertDialog::Component.new.tap do |dialog|
          dialog.with_trigger(data: { action: HOST_ACTION }) { "Delete" }
          dialog.with_title { "Sure?" }
          dialog.with_description { "This cannot be undone." }
          dialog.with_action { "Confirm" }
          dialog.with_cancel(data: { action: HOST_ACTION }) { "Cancel" }
        end)

        assert_survival page.find("button[data-action*='#open']", visible: :all)["data-action"], "alert trigger"
        assert_survival page.find("[data-slot=alert-dialog-cancel]", visible: :all)["data-action"], "alert cancel"
      end

      def test_toast_trigger_root_keeps_wiring
        render_inline(ToastTrigger::Component.new(
          title: "Saved", data: { controller: HOST_CONTROLLER, action: HOST_ACTION }
        ) { "Notify" })

        button = page.find("[data-slot=toast-trigger]")

        assert_survival button["data-controller"], "toast trigger controller"
        assert_survival button["data-action"], "toast trigger action"
      end

      # --- S2 surfaces: helpers, slot splats, reserved keys ---

      def render_erb(erb)
        ApplicationController.renderer.render(inline: erb, layout: false)
      end

      def test_checkbox_group_helper_keeps_wiring_under_host_data
        html = render_erb(<<~ERB)
          <%= poetry_checkbox_group(data: { controller: "host-probe", action: "click->host#probe" }) do %>x<% end %>
        ERB
        doc = Nokogiri::HTML.fragment(html)
        group = doc.at_css("[data-slot=checkbox-group]")

        assert_includes group["data-controller"], "host-probe"
        assert_includes group["data-controller"], "poetry--core--checkbox-group"
        assert_includes group["data-action"], "host#probe"
        assert_includes group["data-action"], "poetry--core--checkbox-group#changed"
      end

      def test_message_scroller_item_keeps_caller_data_and_reserves_message_id
        html = render_erb(<<~ERB)
          <%= poetry_message_scroller_item(id: "m-1", data: { controller: "host-probe" },
                                           "data-message-id" => "evil") { "hi" } %>
        ERB
        item = Nokogiri::HTML.fragment(html).at_css("[data-slot=message-scroller-item]")

        assert_includes item["data-controller"], "host-probe", "caller data was discarded"
        assert_equal "m-1", item["data-message-id"], "the anchoring identity is reserved"
      end

      def test_sidebar_trigger_and_rail_keep_toggle_wiring_under_host_data
        html = render_erb(<<~ERB)
          <%= poetry_sidebar_trigger(data: { action: "click->host#probe" }) %>
          <%= poetry_sidebar_rail(data: { action: "click->host#probe" }) %>
        ERB
        doc = Nokogiri::HTML.fragment(html)
        trigger = doc.at_css("[data-slot=sidebar-trigger]")
        rail = doc.at_css("[data-slot=sidebar-rail]")

        [trigger, rail].each do |el|
          assert_includes el["data-action"], "host#probe"
          assert_includes el["data-action"], "#toggle"
        end
      end

      def test_toast_action_and_attachment_slots_keep_wiring
        render_inline(Toast::Component.new) do |toast|
          toast.with_title { "Saved" }
          toast.with_action(data: { action: HOST_ACTION }) { "Undo" }
        end

        assert_survival page.find("[data-slot=toast-action]", visible: :all)["data-action"], "toast action"

        render_inline(Attachment::Component.new) do |attachment|
          attachment.with_title { "report.pdf" }
          attachment.with_action(label: "Remove", data: { action: HOST_ACTION }) { "x" }
          attachment.with_trigger(class: "px-8", data: { action: HOST_ACTION }) { "Attach" }
        end

        action = page.find("[data-slot=attachment-action]", visible: :all)
        trigger = page.find("[data-slot=attachment-trigger]", visible: :all)

        assert_includes action["data-action"].to_s, "host#probe", "attachment action host token lost"
        assert_includes trigger["data-action"].to_s, "host#probe", "attachment trigger host token lost"
        assert_includes trigger["class"], "px-8", "attachment trigger caller class lost"
      end

      def test_tag_group_row_carries_caller_options_and_reserves_data_value
        render_inline(TagGroup::Component.new(label: "Tags")) do |group|
          group.with_tag(value: "ruby", "aria-describedby" => "hint", "data-value" => "evil")
        end

        row = page.find("[data-slot=tag-group-tag]", visible: :all)

        assert_equal "hint", row["aria-describedby"], "caller options were discarded"
        assert_equal "ruby", row["data-value"], "the collection identity is reserved"
      end

      def test_select_item_reserves_data_value_against_caller_override
        render_inline(Select::Component.new(name: "fruit", "aria-label" => "Fruit")) do |select|
          select.with_item(value: "apple", "data-value" => "evil") { "Apple" }
        end

        assert_equal "apple", page.find("[data-slot=select-item]", visible: :all)["data-value"]
      end

      def test_submit_item_reserves_the_transparent_form
        render_inline(DropdownMenu::Component.new) do |menu|
          menu.with_trigger { "Open" }
          menu.with_item(submit: "/archive", form: { class: "big-form" },
                         data: { action: HOST_ACTION }) { "Archive" }
        end

        form = page.find("form", visible: :all)
        item = page.find("[data-slot=dropdown-menu-item]", visible: :all)

        assert_includes form["class"].to_s, "contents", "the display:contents form is reserved"
        refute_includes form["class"].to_s, "big-form"
        assert_survival item["data-action"], "submit item"
      end
    end
  end
end
