# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # M7 DoD: a model-bound form renders with errors + a11y + i18n.
    class FormsTest < ActionDispatch::IntegrationTest
      class Contact
        include ActiveModel::Model

        attr_accessor :email, :nickname

        validates :email, presence: true
      end

      FORM_ERB = <<~ERB
        <%= form_with(model: model, url: "/contacts", builder: Poetry::Ui::FormBuilder) do |form| %>
          <%= form.field(:email, hint: "We never share it.") %>
          <%= form.field(:nickname) %>
        <% end %>
      ERB

      def render_form(model)
        ApplicationController.renderer.render(inline: FORM_ERB, locals: { model: model }, layout: false)
      end

      def test_a_clean_model_renders_label_input_hint_wired_together
        html = render_form(Contact.new(email: "a@b.c"))

        email_input = html[/<input[^>]*name="[^"]*\[email\]"[^>]*>/]
        id = email_input[/id="([^"]+)"/, 1]

        assert id, "the input carries the field id"
        assert_includes html, %(<label class=), "a poetry Label renders"
        assert_includes html, %(for="#{id}")
        assert_includes html, 'value="a@b.c"'
        assert_includes html, %(aria-describedby="#{id}-hint")
        assert_includes html, "We never share it."
        refute_includes html, 'aria-invalid="true"' # the aria-invalid: CLASS variants are always present
      end

      def test_presence_validation_becomes_aria_required_only
        html = render_form(Contact.new)
        email_input = html[/<input[^>]*name="[^"]*\[email\]"[^>]*>/]

        assert_includes email_input, 'aria-required="true"'
        refute_match(/\srequired[\s>=]/, email_input, "the native attribute is never set (the aria-required-only rule)")
        refute_includes html[/<input[^>]*name="[^"]*\[nickname\]"[^>]*>/], "aria-required"
      end

      def test_model_errors_auto_flow_into_the_error_quartet
        model = Contact.new
        model.validate

        html = render_form(model)
        email_input = html[/<input[^>]*name="[^"]*\[email\]"[^>]*>/]
        id = email_input[/id="([^"]+)"/, 1]

        assert_includes email_input, 'aria-invalid="true"'
        assert_includes email_input, %(aria-describedby="#{id}-error #{id}-hint")
        assert_match(%r{<p id="#{id}-error"[^>]*>Email can(?:'|&#39;)t be blank</p>}, html)
        assert_includes html, 'data-invalid="true"'
      end

      # -- The toggle-family builder methods (check_box / switch) ------------

      class Settings
        include ActiveModel::Model

        attr_accessor :terms, :notifications

        validates :terms, presence: true
      end

      TOGGLES_ERB = <<~ERB
        <%= form_with(model: model, url: "/settings", builder: Poetry::Ui::FormBuilder) do |form| %>
          <%= form.check_box(:terms) %>
          <%= form.switch(:notifications) %>
        <% end %>
      ERB

      def render_toggles(model)
        html = ApplicationController.renderer.render(inline: TOGGLES_ERB, locals: { model: model }, layout: false)
        Nokogiri::HTML5.fragment(html)
      end

      def test_check_box_derives_name_id_and_the_hidden_pair_from_the_object
        fragment = render_toggles(Settings.new(terms: "1"))
        control = fragment.css('[data-slot="checkbox"]').first
        inputs = fragment.css('input[name="poetry_ui_forms_test_settings[terms]"]')

        assert_equal "poetry_ui_forms_test_settings_terms", control["id"]
        assert_equal "true", control["aria-checked"], "checked from the object's attribute truthiness"
        # Tags::CheckBox parity: the "0" hidden FIRST, then the checked "1".
        assert_equal(%w[hidden checkbox], inputs.map { |input| input["type"] })
        assert_equal "0", inputs.first["value"]
        assert_equal "1", inputs.last["value"]
        assert inputs.last.key?("checked")
      end

      def test_check_box_truthiness_follows_rails_boolean_casting
        control = render_toggles(Settings.new(terms: "0")).css('[data-slot="checkbox"]').first

        assert_equal "false", control["aria-checked"], '"0" casts false - Rails semantics, not Ruby truthiness'
      end

      def test_check_box_presence_validation_becomes_aria_required_only
        fragment = render_toggles(Settings.new)
        control = fragment.css('[data-slot="checkbox"]').first

        assert_equal "true", control["aria-required"]
        assert(fragment.css("input").none? { |input| input.key?("required") },
               "never the native attribute (the aria-required-only rule)")
      end

      def test_switch_is_the_check_box_mapping_wearing_switch_semantics
        fragment = render_toggles(Settings.new(notifications: true))
        control = fragment.css('[data-slot="switch"]').first
        inputs = fragment.css('input[name="poetry_ui_forms_test_settings[notifications]"]')

        assert_equal "switch", control["role"], "role=switch announces on/off - the reason it is not a styled checkbox"
        assert_equal "poetry_ui_forms_test_settings_notifications", control["id"]
        assert_equal "true", control["aria-checked"]
        assert_equal(%w[hidden checkbox], inputs.map { |input| input["type"] })
        refute control["aria-required"]
      end

      # -- The radio_group builder method (N5 exclusive choice) --------------

      class Subscription
        include ActiveModel::Model

        attr_accessor :plan

        validates :plan, presence: true
      end

      PLAN_ERB = <<~ERB
        <%= form_with(model: model, url: "/subscriptions", builder: Poetry::Ui::FormBuilder) do |form| %>
          <%= form.radio_group(:plan, [%w[monthly Monthly], %w[yearly Yearly]], hint: "Change anytime.") %>
        <% end %>
      ERB

      def render_plan(model)
        html = ApplicationController.renderer.render(inline: PLAN_ERB, locals: { model: model }, layout: false)
        Nokogiri::HTML5.fragment(html)
      end

      def test_radio_group_derives_the_field_quartet_and_the_hidden_radios_from_the_object
        fragment = render_plan(Subscription.new(plan: "yearly"))
        root = fragment.css('[data-slot="radio-group"]').first
        inputs = fragment.css('input[type="radio"]')

        assert_equal "poetry_ui_forms_test_subscription_plan", root["id"], "the Field id lands on the root"
        assert_equal "Plan", root["aria-label"]
        assert_equal "true", root["aria-required"], "presence validator -> aria-required (root, never native)"
        assert_includes root["aria-describedby"], "-hint"
        # collection_radio_buttons-identical serialization: shared derived
        # name, the object's value checked.
        assert_equal(%w[poetry_ui_forms_test_subscription[plan] poetry_ui_forms_test_subscription[plan]],
                     inputs.map { |input| input["name"] })
        assert inputs.find { |input| input["value"] == "yearly" }.key?("checked")
        refute inputs.find { |input| input["value"] == "monthly" }.key?("checked")
        assert(fragment.css("input").none? { |input| input.key?("required") })
        # Item labels pair via for= the button ids (derived from the root id).
        assert_equal(2, fragment.css("label").count { |label| label["for"]&.start_with?("#{root["id"]}-") })
      end

      def test_radio_group_model_errors_flow_into_aria_invalid_items_and_the_root_describedby
        model = Subscription.new
        model.validate

        fragment = render_plan(model)
        root = fragment.css('[data-slot="radio-group"]').first
        items = fragment.css('[data-slot="radio-group-item"]')

        assert_equal "#{root["id"]}-error #{root["id"]}-hint", root["aria-describedby"],
                     "error before hint, on the ROOT (group-level)"
        assert(items.all? { |item| item["aria-invalid"] == "true" }, "the destructive ring on every item")
        assert_includes fragment.css("[data-slot='field-error']").first.text, "blank"
        # Nothing checked, nothing submits: no radio checked, no hidden
        # blank input inside the group.
        assert(fragment.css("input").none? { |input| input.key?("checked") })
        assert_empty root.css('input[type="hidden"]')
      end

      # -- The slider builder method (N5 bounded numeric) ---------------------

      class Mixer
        include ActiveModel::Model

        attr_accessor :volume, :price_range
      end

      MIXER_ERB = <<~ERB
        <%= form_with(model: model, url: "/mixers", builder: Poetry::Ui::FormBuilder) do |form| %>
          <%= form.slider(:volume, hint: "Applies immediately.") %>
          <%= form.slider(:price_range, range: true, min: 0, max: 1000, step: 10,
                          label: ["Minimum price", "Maximum price"]) %>
        <% end %>
      ERB

      def render_mixer(model)
        html = ApplicationController.renderer.render(inline: MIXER_ERB, locals: { model: model }, layout: false)
        Nokogiri::HTML5.fragment(html)
      end

      def test_slider_derives_the_single_thumb_from_the_object_with_the_field_wiring
        fragment = render_mixer(Mixer.new(volume: 40, price_range: [200, 800]))
        single = fragment.css('[data-slot="slider"]').first
        thumb = single.css('[data-slot="slider-thumb"]').first

        assert_equal "poetry_ui_forms_test_mixer_volume", single["id"]
        assert_equal "40", thumb["aria-valuenow"]
        assert_equal "Volume", thumb["aria-label"], "single mode derives the thumb name from the field label"
        assert_includes thumb["aria-describedby"], "-hint", "Field hint wires to the THUMB"
        assert_equal "poetry_ui_forms_test_mixer[volume]", single.css("input").first["name"]
      end

      def test_slider_range_reads_the_array_and_submits_rails_array_params
        fragment = render_mixer(Mixer.new(price_range: [200, 800]))
        range = fragment.css('[data-slot="slider"]').last
        inputs = range.css("input")

        assert_equal 2, range.css('[data-slot="slider-thumb"]').size
        assert_equal(%w[poetry_ui_forms_test_mixer[price_range][] poetry_ui_forms_test_mixer[price_range][]],
                     inputs.map { |input| input["name"] }, "name[] - params: ['200', '800']")
        assert_equal(%w[200 800], inputs.map { |input| input["value"] })
        assert_equal(["Minimum price", "Maximum price"],
                     range.css('[data-slot="slider-thumb"]').map { |thumb| thumb["aria-label"] })
      end

      def test_slider_range_without_a_value_defaults_to_the_full_span
        fragment = render_mixer(Mixer.new(volume: 10))
        range = fragment.css('[data-slot="slider"]').last

        assert_equal(%w[0 1000],
                     range.css('[data-slot="slider-thumb"]').map { |thumb| thumb["aria-valuenow"] })
      end

      # -- The as: :textarea switch on #field (N5 field-shaped controls) ------

      class Profile
        include ActiveModel::Model

        attr_accessor :bio

        validates :bio, presence: true
      end

      BIO_ERB = <<~ERB
        <%= form_with(model: model, url: "/profiles", builder: Poetry::Ui::FormBuilder) do |form| %>
          <%= form.field(:bio, as: :textarea, rows: 4, hint: "Markdown is supported.") %>
        <% end %>
      ERB

      def render_bio(model)
        html = ApplicationController.renderer.render(inline: BIO_ERB, locals: { model: model }, layout: false)
        Nokogiri::HTML5.fragment(html)
      end

      def test_field_as_textarea_renders_the_wired_quartet
        fragment = render_bio(Profile.new(bio: "Hello.\nWorld."))
        textarea = fragment.css("textarea").first

        assert_equal "poetry_ui_forms_test_profile_bio", textarea["id"]
        assert_equal "poetry_ui_forms_test_profile[bio]", textarea["name"]
        assert_equal "4", textarea["rows"]
        assert_equal "Hello.\nWorld.", textarea.text, "the value is the element content"
        assert_equal "true", textarea["aria-required"]
        refute textarea.key?("required")
        assert_includes textarea["aria-describedby"], "-hint"
        assert_equal 1, fragment.css(%(label[for="#{textarea["id"]}"])).size
      end

      def test_field_as_textarea_model_errors_flow
        model = Profile.new
        model.validate

        textarea = render_bio(model).css("textarea").first

        assert_equal "true", textarea["aria-invalid"]
        assert_equal "#{textarea["id"]}-error #{textarea["id"]}-hint", textarea["aria-describedby"]
      end

      # -- The otp_field builder method (N5 verification codes) ---------------

      class Verification
        include ActiveModel::Model

        attr_accessor :code

        validates :code, presence: true
      end

      CODE_ERB = <<~ERB
        <%= form_with(model: model, url: "/verifications", builder: Poetry::Ui::FormBuilder) do |form| %>
          <%= form.otp_field(:code, groups: [3, 3], hint: "Enter the 6-digit code we sent you.") %>
        <% end %>
      ERB

      def render_code(model)
        html = ApplicationController.renderer.render(inline: CODE_ERB, locals: { model: model }, layout: false)
        Nokogiri::HTML5.fragment(html)
      end

      def test_otp_field_wires_the_one_real_input_through_the_field
        fragment = render_code(Verification.new)
        input = fragment.css('[data-slot="input-otp"]').first

        assert_equal "poetry_ui_forms_test_verification_code", input["id"], "the label-for target is the input"
        assert_equal "poetry_ui_forms_test_verification[code]", input["name"]
        assert_equal "one-time-code", input["autocomplete"]
        assert_equal "true", input["aria-required"]
        refute input.key?("required")
        assert_includes input["aria-describedby"], "-hint"
        assert_equal 1, fragment.css(%(label[for="#{input["id"]}"])).size
        assert_equal 6, fragment.css('[data-slot="input-otp-slot"]').size
      end

      def test_otp_field_never_round_trips_the_rejected_code
        model = Verification.new(code: "123456")
        model.errors.add(:code, "is invalid")

        fragment = render_code(model)
        input = fragment.css('[data-slot="input-otp"]').first

        assert_nil input["value"], "a rejected code is dead - blanked on the error re-render"
        assert_equal "true", input["aria-invalid"]
        assert_equal "#{input["id"]}-error #{input["id"]}-hint", input["aria-describedby"]
        assert(fragment.css('[data-slot="input-otp-slot"]').all? { |slot| slot["aria-invalid"] == "true" })
      end

      # -- The poetry_select builder method (N5 listbox capstone) --------------

      class Ticket
        include ActiveModel::Model

        attr_accessor :department, :region

        validates :department, presence: true
      end

      TICKET_ERB = <<~ERB
        <%= form_with(model: model, url: "/tickets", builder: Poetry::Ui::FormBuilder) do |form| %>
          <%= form.poetry_select(:department, [["Engineering", "eng"], ["Design", "design"]],
                                 include_blank: "Choose department", hint: "Routes your ticket.") %>
        <% end %>
      ERB

      def render_ticket(model)
        html = ApplicationController.renderer.render(inline: TICKET_ERB, locals: { model: model }, layout: false)
        Nokogiri::HTML5.fragment(html)
      end

      def test_poetry_select_derives_the_field_quartet_and_the_native_select_from_the_object
        fragment = render_ticket(Ticket.new(department: "design"))
        trigger = fragment.css('[data-slot="select-trigger"]').first
        native = fragment.css('select[data-slot="select-native"]').first

        # The Field id lands on the TRIGGER - label[for] click-focuses the combobox.
        assert_equal "poetry_ui_forms_test_ticket_department", trigger["id"]
        assert_equal 1, fragment.css(%(label[for="#{trigger["id"]}"])).size
        assert_includes trigger["aria-describedby"], "-hint"
        assert_equal "true", trigger["aria-required"], "presence validator -> aria-required on the combobox"
        # The hidden native select is the serialization truth: derived name,
        # the object's value selected, native required (constraint validation
        # rides the REAL control - the Select-specific exception).
        assert_equal "poetry_ui_forms_test_ticket[department]", native["name"]
        assert native.key?("required")
        assert_equal(["", "eng", "design"], native.css("option").map { |option| option["value"] })
        assert native.css('option[value="design"]').first.key?("selected")
        # include_blank doubles as the placeholder text + the blank option label.
        assert_equal "Choose department", native.css('option[value=""]').first.text
        assert_equal "Design", fragment.css('[data-slot="select-value"]').first.text,
                     "the display shows the LABEL of the object's value"
        refute trigger.key?("data-placeholder")
      end

      def test_poetry_select_without_a_value_rests_on_the_blank_option
        fragment = render_ticket(Ticket.new)
        trigger = fragment.css('[data-slot="select-trigger"]').first
        native = fragment.css('[data-slot="select-native"]').first

        assert trigger.key?("data-placeholder")
        assert_equal "Choose department", fragment.css('[data-slot="select-value"]').first.text
        assert native.css('option[value=""]').first.key?("selected")
        assert_empty fragment.css('[data-slot="select-item"][aria-selected="true"]')
      end

      def test_poetry_select_model_errors_flow_onto_the_trigger
        model = Ticket.new
        model.validate

        fragment = render_ticket(model)
        trigger = fragment.css('[data-slot="select-trigger"]').first

        assert_equal "true", trigger["aria-invalid"]
        assert_equal "#{trigger["id"]}-error #{trigger["id"]}-hint", trigger["aria-describedby"],
                     "error before hint, on the combobox"
        assert_includes fragment.css('[data-slot="field-error"]').first.text, "blank"
      end

      GROUPED_ERB = <<~ERB
        <%= form_with(model: model, url: "/tickets", builder: Poetry::Ui::FormBuilder) do |form| %>
          <%= form.poetry_select(:region, { "Americas" => [["United States", "us"]],
                                            "Europe" => [["Germany", "de"], ["France", "fr"]] }) %>
        <% end %>
      ERB

      def test_poetry_select_grouped_choices_become_labelled_group_parts
        html = ApplicationController.renderer.render(inline: GROUPED_ERB,
                                                     locals: { model: Ticket.new(region: "de") }, layout: false)
        fragment = Nokogiri::HTML5.fragment(html)
        groups = fragment.css('[data-slot="select-group"]')

        assert_equal 2, groups.size
        assert_equal %w[Americas Europe], fragment.css('[data-slot="select-label"]').map(&:text)
        assert_equal(%w[us de fr],
                     fragment.css('[data-slot="select-native"] option:not([value=""])').map { |o| o["value"] })
        assert_equal "Germany", fragment.css('[data-slot="select-value"]').first.text
      end

      def test_poetry_select_rejects_multiple
        # The controller renderer wraps render-time raises in Template::Error.
        error = assert_raises(ActionView::Template::Error, ArgumentError) do
          ApplicationController.renderer.render(
            inline: <<~ERB, locals: { model: Ticket.new }, layout: false
              <%= form_with(model: model, url: "/tickets", builder: Poetry::Ui::FormBuilder) do |form| %>
                <%= form.poetry_select(:department, %w[eng design], multiple: true) %>
              <% end %>
            ERB
          )
        end

        assert_includes error.message, "multiple"
      end

      def test_labels_come_from_i18n
        I18n.backend.store_translations(:en, activemodel: {
                                          attributes: { "poetry/ui/forms_test/contact": { email: "Work email" } }
                                        })
        html = render_form(Contact.new)

        assert_includes html, ">Work email</label>"
      ensure
        I18n.reload!
      end
    end
  end
end
