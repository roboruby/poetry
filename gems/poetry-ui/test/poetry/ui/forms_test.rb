# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The forms contract: a model-bound form renders with errors + a11y + i18n.
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

      # -- The radio_group builder method (exclusive choice) -----------------

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
        # The group is named by the VISIBLE Field label (aria-labelledby) -
        # for= would be inert on a div (Chrome flags it), and a duplicated
        # aria-label string could drift from the rendered text.
        group_label = fragment.css('label[data-slot="label"]').find { |label| label.text == "Plan" }

        assert_equal group_label["id"], root["aria-labelledby"]
        assert_nil group_label["for"], "no inert label[for] pointing at the group div"
        assert_nil root["aria-label"]
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

      # -- The slider builder method (bounded numeric) ------------------------

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

      # -- The as: :textarea switch on #field (field-shaped controls) ---------

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

      # -- The otp_field builder method (verification codes) ------------------

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

      # -- The poetry_select builder method (listbox capstone) -----------------

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

      # -- The poetry_combobox builder method (the poetry_select twin) ---------

      COMBOBOX_ERB = <<~ERB
        <%= form_with(model: model, url: "/tickets", builder: Poetry::Ui::FormBuilder) do |form| %>
          <%= form.poetry_combobox(:department, [["Engineering", "eng"], ["Design", "design"]],
                                   include_blank: "Choose department", hint: "Routes your ticket.") %>
        <% end %>
      ERB

      def render_combobox_ticket(model)
        html = ApplicationController.renderer.render(inline: COMBOBOX_ERB, locals: { model: model }, layout: false)
        Nokogiri::HTML5.fragment(html)
      end

      def test_poetry_combobox_derives_the_field_quartet_and_the_native_select_from_the_object
        fragment = render_combobox_ticket(Ticket.new(department: "design"))
        trigger = fragment.css('[data-slot="combobox-trigger"]').first
        native = fragment.css('select[data-slot="combobox-native"]').first

        # The Field id lands on the TRIGGER - label[for] click-focuses the combobox.
        assert_equal "poetry_ui_forms_test_ticket_department", trigger["id"]
        assert_equal 1, fragment.css(%(label[for="#{trigger["id"]}"])).size
        assert_includes trigger["aria-describedby"], "-hint"
        assert_equal "true", trigger["aria-required"], "presence validator -> aria-required on the combobox"
        # The hidden native select is the serialization truth: derived name,
        # the object's value selected, native required (the Select-family
        # exception - constraint validation rides the REAL control).
        assert_equal "poetry_ui_forms_test_ticket[department]", native["name"]
        assert native.key?("required")
        assert_equal(["", "eng", "design"], native.css("option").map { |option| option["value"] })
        assert native.css('option[value="design"]').first.key?("selected")
        # include_blank doubles as the placeholder text + the blank option label.
        assert_equal "Choose department", native.css('option[value=""]').first.text
        assert_equal "Design", fragment.css('[data-slot="combobox-value"]').first.text,
                     "the display shows the LABEL of the object's value"
        refute trigger.key?("data-placeholder")
        # The twin-write pair lands on the object's option.
        selected = fragment.css('[data-slot="command-item"][aria-selected="true"]')
        selected_values = selected.map { |item| item["data-value"] }

        assert_equal ["design"], selected_values
        assert selected.first.key?("data-selected"), "the committed option carries bare data-selected"
      end

      def test_poetry_combobox_without_a_value_rests_on_the_blank_option
        fragment = render_combobox_ticket(Ticket.new)
        trigger = fragment.css('[data-slot="combobox-trigger"]').first
        native = fragment.css('[data-slot="combobox-native"]').first

        assert trigger.key?("data-placeholder")
        assert_equal "Choose department", fragment.css('[data-slot="combobox-value"]').first.text
        assert native.css('option[value=""]').first.key?("selected")
        assert_empty fragment.css('[data-slot="command-item"][aria-selected="true"]')
      end

      def test_poetry_combobox_model_errors_flow_onto_the_trigger
        model = Ticket.new
        model.validate

        fragment = render_combobox_ticket(model)
        trigger = fragment.css('[data-slot="combobox-trigger"]').first

        assert_equal "true", trigger["aria-invalid"]
        assert_equal "#{trigger["id"]}-error #{trigger["id"]}-hint", trigger["aria-describedby"],
                     "error before hint, on the combobox"
        assert_includes fragment.css('[data-slot="field-error"]').first.text, "blank"
      end

      GROUPED_COMBOBOX_ERB = <<~ERB
        <%= form_with(model: model, url: "/tickets", builder: Poetry::Ui::FormBuilder) do |form| %>
          <%= form.poetry_combobox(:region, { "Americas" => [["United States", "us"]],
                                              "Europe" => [["Germany", "de"], ["France", "fr"]] }) %>
        <% end %>
      ERB

      def test_poetry_combobox_grouped_choices_become_heading_labelled_group_parts
        html = ApplicationController.renderer.render(inline: GROUPED_COMBOBOX_ERB,
                                                     locals: { model: Ticket.new(region: "de") }, layout: false)
        fragment = Nokogiri::HTML5.fragment(html)
        groups = fragment.css('[data-slot="command-group"]')

        assert_equal 2, groups.size
        assert_equal %w[Americas Europe], fragment.css('[data-slot="command-group-heading"]').map(&:text)
        assert_equal(%w[us de fr],
                     fragment.css('[data-slot="combobox-native"] option:not([value=""])').map { |o| o["value"] })
        assert_equal "Germany", fragment.css('[data-slot="combobox-value"]').first.text
      end

      def test_poetry_combobox_multiple_reads_the_array_and_posts_the_rails_array_convention
        html = ApplicationController.renderer.render(
          inline: <<~ERB, locals: { model: Ticket.new(department: %w[design eng]) }, layout: false
            <%= form_with(model: model, url: "/tickets", builder: Poetry::Ui::FormBuilder) do |form| %>
              <%= form.poetry_combobox(:department, %w[eng design ops], multiple: true) %>
            <% end %>
          ERB
        )
        fragment = Nokogiri::HTML5.fragment(html)
        native = fragment.css('[data-slot="combobox-native"]').first

        assert_equal "poetry_ui_forms_test_ticket[department][]", native["name"],
                     "field_name(multiple:) posts the [] convention"
        assert native.key?("multiple")
        assert_equal %w[design eng],
                     fragment.css('[data-slot="combobox-chips"] > [data-slot="combobox-chip"]')
                             .map { |chip| chip["data-value"] },
                     "one chip per model value IN VALUE ORDER"
        # The control_attributes land on the INLINE INPUT (no trigger exists).
        input = fragment.css('[data-slot="command-input"]').first

        assert_equal "poetry_ui_forms_test_ticket_department", input["id"]
        assert_equal fragment.css("label").first["for"], input["id"]
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
      # -- Rails-parity + roster coverage -----------------------------------

      class RosterProfile
        include ActiveModel::Model

        attr_accessor :email, :password, :bio, :query, :api_key, :city, :country,
                      :topics, :roles, :due_on, :starts_on, :volume

        validates :email, presence: true
      end

      def render_snippet(erb, model: RosterProfile.new)
        ApplicationController.renderer.render(
          inline: "<%= form_with(model: model, url: \"/profiles\", " \
                  "builder: Poetry::Ui::FormBuilder) do |form| %>#{erb}<% end %>",
          locals: { model: model }, layout: false
        )
      end

      def test_typed_inputs_map_to_input_types_and_password_never_round_trips
        html = render_snippet(
          "<%= form.email_field(:email) %><%= form.password_field(:password) %>",
          model: RosterProfile.new(email: "a@b.c", password: "hunter2")
        )

        assert_includes html[/<input[^>]*\[email\][^>]*>/], 'type="email"'
        password = html[/<input[^>]*\[password\][^>]*>/]

        assert_includes password, 'type="password"'
        refute_includes password, "hunter2", "password values never round-trip"
      end

      def test_text_area_and_rails8_respelling_render_a_textarea_field
        html = render_snippet("<%= form.text_area(:bio) %>")

        assert_includes html, "<textarea"
        assert_includes html, %(name="poetry_ui_forms_test_roster_profile[bio]")

        skip unless ActionView::VERSION::MAJOR >= 8

        respelled = render_snippet("<%= form.textarea(:bio) %><%= form.checkbox(:query) %>")

        assert_includes respelled, "<textarea"
        assert_includes respelled, 'role="checkbox"'
      end

      def test_search_and_sensitive_fields_wear_the_quartet_wiring
        html = render_snippet("<%= form.search_field(:query) %>" \
                              "<%= form.sensitive_input(:api_key, hint: \"Keep it secret.\") %>",
                              model: RosterProfile.new(api_key: "sk-123"))

        assert_includes html, 'type="search"'
        assert_includes html, "Keep it secret."
        assert_includes html, "sk-123"
      end

      def test_autocomplete_renders_suggestions_with_the_input_as_value
        html = render_snippet("<%= form.autocomplete(:city, [\"Lisbon\", [\"Porto\", \"porto\"]]) %>",
                              model: RosterProfile.new(city: "Lis"))

        assert_includes html, 'data-slot="autocomplete"'
        assert_includes html, 'value="Lis"'
        assert_includes html, 'data-label="Lisbon"'
        assert_includes html, 'data-value="porto"'
      end

      def test_native_select_maps_choices_and_include_blank
        html = render_snippet("<%= form.native_select(:country, [[\"USA\", \"us\"]], include_blank: \"Choose...\") %>",
                              model: RosterProfile.new(country: "us"))

        assert_includes html, "<select"
        assert_includes html, "Choose..."
        assert_match(/value="us"[^>]*selected/, html)
      end

      def test_tag_group_posts_array_semantics_with_the_clearing_hidden
        html = render_snippet("<%= form.tag_group(:topics) %>", model: RosterProfile.new(topics: %w[ruby rails]))

        assert_includes html, %(name="poetry_ui_forms_test_roster_profile[topics][]" value=""),
                        "the leading clear-all hidden"
        assert_includes html, "ruby"
        assert_includes html, "rails"
      end

      def test_checkbox_group_checks_from_the_model_array_without_per_item_hiddens
        html = render_snippet("<%= form.checkbox_group(:roles, [[\"admin\", \"Admin\"], " \
                              "[\"editor\", \"Editor\"]], select_all: true) %>",
                              model: RosterProfile.new(roles: %w[admin]))

        boxes = html.scan(/<input[^>]*\[roles\]\[\][^>]*>/)
        hidden_clears = boxes.count { |b| b.include?('type="hidden"') && b.include?('value=""') }

        assert_equal 1, hidden_clears, "exactly ONE clearing hidden - never per-item unchecked pairs"
        assert_includes html, %(>Admin</label>)
        assert_match(/checked[^>]*value="admin"|value="admin"[^>]*checked/, html)
        assert_includes html, 'data-poetry--core--checkbox-group-target="all"', "the select-all parent"
      end

      def test_date_picker_and_calendar_map_as_group_fields
        html = render_snippet("<%= form.date_picker(:due_on) %><%= form.calendar(:starts_on) %>",
                              model: RosterProfile.new(due_on: "2026-06-12"))

        assert_includes html, 'data-slot="date-picker"'
        assert_includes html, 'data-slot="calendar"'
        assert_includes html, "2026-06-12"
      end

      def test_calendar_receives_the_model_date_as_selected
        html = render_snippet("<%= form.calendar(:starts_on) %>",
                              model: RosterProfile.new(starts_on: "2026-06-12"))

        assert_match(/<input type="hidden" name="[^"]*\[starts_on\]" value="2026-06-12"/, html,
                     "the model date lands in the calendar's hidden input")
        assert_includes html, "data-selected", "the picked day is stamped"
        refute_match(/<div[^>]*\svalue="2026-06-12"/, html,
                     "value: must never leak onto the root as a literal attribute")
      end

      def test_search_and_sensitive_fields_reflect_model_errors_as_aria_invalid
        model = RosterProfile.new(query: "x", api_key: "sk")
        model.errors.add(:query, :invalid)
        model.errors.add(:api_key, :invalid)

        html = render_snippet("<%= form.search_field(:query) %><%= form.sensitive_input(:api_key) %>",
                              model: model)

        invalid_inputs = html.scan(/<input[^>]*aria-invalid="true"[^>]*>/)

        assert_operator invalid_inputs.length, :>=, 2,
                        "both controls carry aria-invalid from model errors (the destructive ring hook)"
      end

      def test_native_select_describedby_lands_on_the_select_itself
        html = render_snippet("<%= form.native_select(:country, [[\"USA\", \"us\"]], hint: \"Pick one.\") %>")

        select_tag = html[/<select[^>]*>/]

        assert_match(/aria-describedby="[^"]*-hint"/, select_tag,
                     "the hint association belongs on the <select>, not the wrapper div")
      end

      def test_tag_group_renders_one_label_with_describedby_on_the_grid
        html = render_snippet("<%= form.tag_group(:topics, hint: \"Comma adds.\") %>",
                              model: RosterProfile.new(topics: %w[ruby]))

        label_ids = html.scan(/id="([^"]*-label)"/).flatten

        assert_equal label_ids.uniq.length, label_ids.length, "no duplicated label id"
        assert_equal 1, html.scan(">Topics<").length, "the caption span is the single visible label"
        grid = html[/<div[^>]*data-slot="tag-group-grid"[^>]*>/]

        assert_match(/aria-describedby="[^"]*-hint"/, grid, "the hint association rides the labelled grid")
      end

      def test_rails_arity_select_and_collection_adapters
        struct = Struct.new(:id, :label_name)
        rows = [struct.new(1, "One"), struct.new(2, "Two")]
        html = ApplicationController.renderer.render(
          inline: "<%= form_with(model: model, url: \"/p\", builder: Poetry::Ui::FormBuilder) do |form| %>" \
                  "<%= form.collection_select(:country, rows, :id, :label_name, include_blank: true) %>" \
                  "<%= form.collection_radio_buttons(:city, rows, :id, :label_name) %><% end %>",
          locals: { model: RosterProfile.new, rows: rows }, layout: false
        )

        assert_includes html, "One"
        assert_includes html, 'role="radiogroup"'
      end

      def test_range_field_maps_to_the_slider
        html = render_snippet("<%= form.range_field(:email) %>")

        assert_includes html, 'data-slot="slider"', "range_field renders the Slider, never a naked native range"
      end

      def test_submit_renders_a_poetry_button_with_the_rails_default_label
        html = render_snippet("<%= form.submit %>")

        assert_match(/<button[^>]*type="submit"/, html)
        assert_includes html, "Create Roster profile"
      end

      def test_fieldset_and_group_yield_the_builder
        html = render_snippet("<%= form.fieldset(legend: \"Identity\") do |f| %><%= f.field(:email) %><% end %>")

        assert_includes html, "<fieldset"
        assert_includes html, "Identity"
        assert_includes html, %(name="poetry_ui_forms_test_roster_profile[email]")
      end

      def test_fields_for_inherits_the_poetry_builder
        html = ApplicationController.renderer.render(
          inline: "<%= form_with(model: model, url: \"/p\", builder: Poetry::Ui::FormBuilder) do |form| %>" \
                  "<%= form.fields_for(:query, sub) do |subform| %><%= subform.field(:email) %><% end %><% end %>",
          locals: { model: RosterProfile.new, sub: RosterProfile.new }, layout: false
        )

        assert_includes html, %(name="poetry_ui_forms_test_roster_profile[query][email]")
        assert_match(/\[query\]\[email\][^>]*/, html)
        assert_includes html, 'data-slot="field"', "the nested builder is still poetry"
      end
      # -- Wave 2: f.input inference + f.association ------------------------

      class Article
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :title, :string
        attribute :body, :string
        attribute :email, :string
        attribute :published, :boolean
        attribute :quantity, :integer
        attribute :released_on, :date

        validates :title, length: { maximum: 80 }
        validates :quantity, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 99,
                                             only_integer: true }

        def self.type_for_attribute(name)
          name == "body" ? Struct.new(:type).new(:text) : super
        end
      end

      def render_form_case(erb, model:, locals: {})
        ApplicationController.renderer.render(
          inline: "<%= form_with(model: model, url: \"/a\", " \
                  "builder: Poetry::Ui::FormBuilder) do |form| %>#{erb}<% end %>",
          locals: { model: model, **locals }, layout: false
        )
      end

      def test_input_infers_from_name_heuristics_column_types_and_validators
        html = render_form_case("<%= form.input(:email) %><%= form.input(:body) %>" \
                                "<%= form.input(:title) %><%= form.input(:quantity) %>",
                                model: Article.new)

        assert_includes html[/<input[^>]*\[email\][^>]*>/], 'type="email"', "name heuristic"
        assert_includes html, "<textarea", "text column type"
        assert_includes html[/<input[^>]*\[title\][^>]*>/], 'maxlength="80"', "length validator"
        number = html[/<input[^>]*type="number"[^>]*>/]

        assert_includes number, 'min="1"'
        assert_includes number, 'max="99"'
        assert_includes number, 'step="1"'
      end

      def test_input_boolean_renders_the_horizontal_field_and_switch_the_setting_row
        html = render_form_case("<%= form.input(:published) %>", model: Article.new(published: true))

        assert_includes html, 'data-orientation="horizontal"'
        assert_includes html, 'role="checkbox"'

        switched = render_form_case("<%= form.input(:published, switch: true) %>", model: Article.new)

        assert_includes switched, 'data-orientation="setting"'
        assert_includes switched, 'role="switch"'
      end

      def test_input_collection_and_as_overrides
        html = render_form_case("<%= form.input(:title, collection: [[\"Draft\", \"draft\"]]) %>" \
                                "<%= form.input(:body, as: :string) %>", model: Article.new)

        assert_includes html, 'data-slot="select"'
        assert_includes html[/<input[^>]*\[body\][^>]*>/].to_s, 'type="text"', "as: beats the column type"
      end

      def test_input_datetime_raises_with_guidance
        error = assert_raises(ActionView::Template::Error) do
          render_form_case("<%= form.input(:created_at) %>", model: Timestamped.new)
        end

        assert_match(/as: :date or as: :time/, error.message)
      end

      class Timestamped
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :created_at, :datetime
      end

      def test_input_hint_reads_the_poetry_form_then_simple_form_i18n_chain
        I18n.backend.store_translations(:en,
                                        poetry_form: { hints: {
                                          "poetry/ui/forms_test/article": { email: "From poetry_form." }
                                        } })
        I18n.backend.store_translations(:en,
                                        simple_form: { hints: {
                                          "poetry/ui/forms_test/article": { title: "From simple_form." }
                                        } })

        html = render_form_case("<%= form.input(:email) %><%= form.input(:title) %>", model: Article.new)

        assert_includes html, "From poetry_form."
        assert_includes html, "From simple_form.", "simple_form locale keys keep working"
      end

      # -- association stubs (no database) ---------------------------------

      FakeCompany = Struct.new(:id, :name)
      FakeReflection = Struct.new(:macro, :klass, :foreign_key, keyword_init: true)

      class FakeCompanyRelation
        def self.all = [FakeCompany.new(1, "Initech"), FakeCompany.new(2, "Acme")]
      end

      class Employment
        include ActiveModel::Model

        attr_accessor :company_id, :team_ids

        def self.reflect_on_association(name)
          case name
          when :company then FakeReflection.new(macro: :belongs_to, klass: FakeCompanyRelation,
                                                foreign_key: "company_id")
          when :teams then FakeReflection.new(macro: :has_many, klass: FakeCompanyRelation, foreign_key: nil)
          end
        end
      end

      def test_association_belongs_to_renders_a_combobox_on_the_foreign_key
        html = render_form_case("<%= form.association(:company) %>", model: Employment.new(company_id: 2))

        assert_includes html, 'data-slot="combobox"'
        assert_includes html, %(name="poetry_ui_forms_test_employment[company_id]")
        assert_includes html, "Initech"
        assert_match(/Acme/, html)
      end

      def test_association_collection_macro_renders_the_checkbox_group_on_ids
        html = render_form_case("<%= form.association(:teams) %>", model: Employment.new(team_ids: [1]))

        assert_includes html, %(name="poetry_ui_forms_test_employment[team_ids][]")
        assert_includes html, 'data-controller="poetry--core--checkbox-group"'
        assert_match(/checked[^>]*value="1"|value="1"[^>]*checked/, html)
      end

      def test_association_as_radio_group_flips_the_pair_order
        html = render_form_case("<%= form.association(:company, as: :radio_group) %>", model: Employment.new)

        assert_includes html, 'role="radiogroup"'
        assert_match(/value="1"/, html)
        assert_includes html, "Initech", "labels stay labels after the flip"
      end

      def test_association_errors_flow_through_the_dual_key_lookup
        model = Employment.new
        model.errors.add(:company, "must exist")
        html = render_form_case("<%= form.association(:company) %>", model: model)

        assert_includes html, "Company must exist"
        assert_includes html, 'data-invalid="true"'
      end

      def test_required_skips_conditional_and_mismatched_context_validators
        model_class = Class.new do
          include ActiveModel::Model

          attr_accessor :nick, :tos

          def self.name = "ContextModel"
          validates :nick, presence: true, on: :update
          validates :tos, presence: true, if: -> { false }
        end
        html = ApplicationController.renderer.render(
          inline: "<%= form_with(model: model, url: \"/c\", builder: Poetry::Ui::FormBuilder) do |form| %>" \
                  "<%= form.field(:nick) %><%= form.field(:tos) %><% end %>",
          locals: { model: model_class.new }, layout: false
        )

        refute_includes html, "aria-required", "on: :update never claims required on a new record; " \
                                               "conditional validators never claim it at all"
      end
    end
  end
end
