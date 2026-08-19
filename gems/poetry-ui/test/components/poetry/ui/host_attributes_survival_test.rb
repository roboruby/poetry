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
    end
  end
end
