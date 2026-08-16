# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The W1 builder-coverage gate (the form-builder plan): every
    # form-participant component in the registry must be reachable from
    # Poetry::Ui::FormBuilder, and every registry component must be
    # CLASSIFIED - mapped or exempt - so a new component cannot ship
    # without deciding its form story (the skill-families partition
    # pattern).
    class FormBuilderCoverageTest < ActiveSupport::TestCase
      # component key (registry name, demodulized) => builder method
      BUILDER_MAPPED = {
        "autocomplete" => :autocomplete,
        "button" => :submit,
        "calendar" => :calendar,
        "checkbox" => :check_box,
        "combobox" => :poetry_combobox,
        "date_field" => :date_field,
        "date_picker" => :date_picker,
        "field" => :field,
        "field_group" => :group,
        "fieldset" => :fieldset,
        "file_input" => :file_input,
        "input" => :field,
        "input_otp" => :otp_field,
        "native_select" => :native_select,
        "number_field" => :number_field,
        "radio_group" => :radio_group,
        "search_field" => :search_field,
        "select" => :poetry_select,
        "sensitive_input" => :sensitive_input,
        "slider" => :slider,
        "switch" => :switch,
        "tag_group" => :tag_group,
        "textarea" => :text_area,
        "time_field" => :time_field
      }.freeze

      # Not model-attribute form controls: display, overlay, navigation,
      # layout-only, and infrastructure components. A component moving OUT
      # of this list must gain a BUILDER_MAPPED entry. Two conscious
      # non-mappings verified 2026-08-16: data_table DOES post
      # (selection_name[] row checkboxes) but as a collection operation,
      # never a model attribute; questionnaire OWNS whole forms (a flow,
      # not a control). toggle/toggle_group/tree carry no name: at all
      # (pressed/selection state is view state).
      FORM_EXEMPT = %w[
        accordion alert alert_dialog aspect_ratio attachment avatar badge
        breadcrumb bubble button_group card carousel clipboard_text
        code_block collapsible command command_dialog context_menu
        data_table deferred dialog drawer dropdown_menu empty
        field_separator hover_card icon input_group item kbd label link
        marker menubar message message_scroller metadata_list meter
        navigation_menu pagination popover progress questionnaire
        resizable scroll_area separator sheet sidebar skeleton spinner
        stat table tabs timeline toast toast_trigger toaster toggle
        toggle_group toolbar tooltip tree typeset
      ].freeze

      def test_the_partition_covers_the_registry_exactly
        roster = Poetry::Core::Registry.new(source_root: Poetry::Ui.root)
                                       .components
                                       .map { |c| c.name.sub("Poetry::Ui::", "").sub(/(::)?Component\z/, "") }
                                       .map { |n| n.split("::").map(&:underscore).join("_") }

        classified = (BUILDER_MAPPED.keys + FORM_EXEMPT).sort

        assert_equal roster.sort, classified,
                     "every registry component must be classified: builder-mapped or form-exempt"
      end

      def test_every_mapped_method_exists_on_the_builder
        BUILDER_MAPPED.each_value do |method|
          assert_includes Poetry::Ui::FormBuilder.instance_methods, method,
                          "FormBuilder must answer ##{method}"
        end
      end
    end
  end
end
