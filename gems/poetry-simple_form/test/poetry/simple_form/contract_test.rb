# frozen_string_literal: true

require "test_helper"

module Poetry
  module SimpleForm
    # The bridge's rendering contract, type by type: every COVERAGE entry
    # renders the component it claims, the quartet derives required/error
    # state the way the native builder does, input_html lands on the control
    # minus class and id, poetry: wins last, collections honor simple_form's
    # label_method/value_method and its detection chain, and the
    # simple_form.* i18n keys keep resolving.
    class ContractTest < ActionDispatch::IntegrationTest
      class Region
        attr_reader :name, :cities

        def initialize(name, cities)
          @name = name
          @cities = cities
        end
      end

      Plan = Struct.new(:code, :title, :id) do
        def name = title
      end

      class Record
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :name, :string
        attribute :nickname, :string
        attribute :bio, :string
        attribute :active, :boolean
        attribute :seats, :integer
        attribute :price, :decimal
        attribute :ratio, :float
        attribute :starts_on, :date
        attribute :at, :time
        attribute :ships_at, :datetime
        attribute :plan, :string
        attribute :city, :string
        attribute :zone, :string
        attribute :file, :string
        validates :name, presence: true

        def self.name = "Record"
      end

      REGIONS = [Region.new("Europe", %w[Berlin Lisbon]), Region.new("Asia", %w[Tokyo])].freeze
      PLANS = [Plan.new("starter", "Starter", 1), Plan.new("team", "Team", 2)].freeze

      # simple_form type => [attribute, extra options] for the table test.
      SETUP = Hash.new(["name", ""]).merge(
        "text" => ["bio", ""], "hstore" => ["bio", ""], "json" => ["bio", ""], "jsonb" => ["bio", ""],
        "boolean" => ["active", ""], "switch" => ["active", ""],
        "integer" => ["seats", ""], "decimal" => ["price", ""], "float" => ["ratio", ""],
        "range" => ["seats", ""], "slider" => ["seats", ""],
        "date" => ["starts_on", ""], "date_picker" => ["starts_on", ""], "calendar" => ["starts_on", ""],
        "time" => ["at", ""], "datetime" => ["ships_at", ""],
        # FileInput's default variant renders the Input component AS the control; only the dropzone root carries the marker.
        "file" => ["file", ", input_html: { variant: :dropzone }"],
        "select" => ["plan", ", collection: %w[starter team]"], "native_select" => ["plan", ", collection: %w[starter team]"],
        "combobox" => ["plan", ", collection: %w[starter team]"], "autocomplete" => ["city", ", collection: %w[Berlin Lisbon]"],
        "radio_buttons" => ["plan", ", collection: %w[starter team]"], "check_boxes" => ["plan", ", collection: %w[starter team]"],
        "grouped_select" => ["city", ", collection: regions, group_method: :cities"],
        "time_zone" => ["zone", ""]
      ).freeze

      def render_sf(erb, model: Record.new, locals: {})
        ApplicationController.renderer.render(
          inline: "<%= simple_form_for(model, url: \"/records\") do |f| %>#{erb}<% end %>",
          locals: { model: model, regions: REGIONS, plans: PLANS, **locals }, layout: false
        )
      end

      def doc(html) = Nokogiri::HTML5.fragment(html)

      def test_every_coverage_entry_renders_the_component_it_claims
        COVERAGE.each do |type, component|
          attribute, extra = SETUP[type.to_s]
          html = render_sf("<%= f.input :#{attribute}, as: :#{type}#{extra} %>")

          assert doc(html).at_css("[data-component=\"#{component}\"]"),
                 "as: :#{type} must render #{component} (COVERAGE says so)"
          assert doc(html).at_css('[data-slot="field"]'), "as: :#{type} must render inside a poetry Field"
        end
      end

      def test_required_derives_from_presence_validators_and_an_explicit_option_wins
        html = render_sf("<%= f.input :name %><%= f.input :nickname %>")
        name = doc(html).at_css('input[name="record[name]"]')
        nickname = doc(html).at_css('input[name="record[nickname]"]')

        assert_equal "true", name["aria-required"], "presence validation -> aria-required"
        assert_nil name["required"], "never the native attribute"
        assert_nil nickname["aria-required"], "no validator, no aria-required"

        html = render_sf("<%= f.input :name, required: false %><%= f.input :nickname, required: true %>")

        assert_nil doc(html).at_css('input[name="record[name]"]')["aria-required"], "required: false overrides inference"
        assert_equal "true", doc(html).at_css('input[name="record[nickname]"]')["aria-required"], "required: true overrides inference"
      end

      def test_errors_reach_every_control_shape
        model = Record.new
        model.errors.add(:plan, "is not available")
        html = render_sf("<%= f.input :plan, collection: %w[starter team] %>", model: model)

        assert_includes html, "Plan is not available"
        assert doc(html).at_css('[data-component="select"]')
        assert doc(html).at_css('[data-slot="field-error"], [role="alert"]'), "the Field's error slot renders"
      end

      def test_input_html_lands_on_the_control_minus_class_and_id
        html = render_sf("<%= f.input :name, input_html: { class: \"custom\", id: \"custom-id\", " \
                         "data: { probe: \"x\" }, autocomplete: \"off\" } %>")
        control = doc(html).at_css('input[name="record[name]"]')

        assert_equal "x", control["data-probe"], "arbitrary attributes pass through"
        assert_equal "off", control["autocomplete"]
        refute_equal "custom-id", control["id"], "the Field owns the control id (label for= depends on it)"
        refute_includes control["class"].to_s.split, "custom", "the component owns its classes"
      end

      def test_poetry_options_win_over_input_html_and_simple_form_options
        html = render_sf("<%= f.input :name, placeholder: \"A\", input_html: { placeholder: \"B\" }, poetry: { placeholder: \"C\" } %>")

        assert_equal "C", doc(html).at_css('input[name="record[name]"]')["placeholder"]
      end

      def test_association_style_collections_honor_label_and_value_methods_and_the_detection_chain
        html = render_sf("<%= f.input :plan, collection: plans %>")

        assert_includes html, "Starter", "detection chain: name (via title alias) labels the item"
        assert doc(html).at_css('[data-value="1"], option[value="1"]'), "detection chain: id is the value"

        html = render_sf("<%= f.input :plan, collection: plans, label_method: :title, value_method: :code %>")

        assert doc(html).at_css('[data-value="starter"], option[value="starter"]'), "value_method: :code is honored"

        html = render_sf("<%= f.input :plan, collection: plans, label_method: ->(p) { p.title.upcase }, value_method: :code %>")

        assert_includes html, "STARTER", "callable label_method is honored"
      end

      def test_simple_form_i18n_keys_keep_resolving
        I18n.backend.store_translations(:en, simple_form: {
          labels: { record: { nickname: "Handle" } },
          hints: { record: { nickname: "Shown on your profile." } },
          placeholders: { record: { nickname: "ada" } }
        })
        html = render_sf("<%= f.input :nickname %>")

        assert_includes html, ">Handle</label>"
        assert_includes html, "Shown on your profile."
        assert_equal "ada", doc(html).at_css('input[name="record[nickname]"]')["placeholder"]
      ensure
        I18n.backend.reload!
      end
    end
  end
end
