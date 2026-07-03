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
