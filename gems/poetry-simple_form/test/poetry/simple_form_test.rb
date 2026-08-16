# frozen_string_literal: true

require "test_helper"

module Poetry
  # The shim's contract: simple_form_for keeps working and every input
  # renders the poetry Field quartet - byte-identical derivation to the
  # native builder, because the shim renders THROUGH it.
  class SimpleFormShimTest < ActionDispatch::IntegrationTest
    class Account
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :name, :string
      attribute :email, :string
      attribute :bio, :string
      attribute :active, :boolean
      attribute :seats, :integer
      attribute :starts_on, :date
      attribute :plan, :string

      validates :name, presence: true, length: { maximum: 40 }
      validates :seats, numericality: { greater_than_or_equal_to: 1, only_integer: true }

      def self.type_for_attribute(name)
        name == "bio" ? Struct.new(:type).new(:text) : super
      end
    end

    def render_sf(erb, model: Account.new, locals: {})
      ApplicationController.renderer.render(
        inline: "<%= simple_form_for(model, url: \"/accounts\") do |f| %>#{erb}<% end %>",
        locals: { model: model, **locals }, layout: false
      )
    end

    def test_f_input_renders_the_poetry_field_quartet
      html = render_sf("<%= f.input :name, hint: \"Shown publicly.\" %>")

      assert_includes html, 'data-slot="field"', "the poetry Field renders"
      assert_includes html, 'data-component="input"'
      name_input = html[/<input[^>]*\[name\][^>]*>/]

      assert_includes name_input, 'aria-required="true"'
      refute_match(/\srequired[\s>=]/, name_input, "aria-required only - never native")
      assert_includes name_input, 'maxlength="40"', "the length validation flows"
      assert_includes html, "Shown publicly."
    end

    def test_type_resolution_rides_simple_form_then_renders_poetry
      html = render_sf("<%= f.input :email %><%= f.input :bio %><%= f.input :seats %>" \
                       "<%= f.input :active %><%= f.input :starts_on %>")

      assert_includes html[/<input[^>]*\[email\][^>]*>/], 'type="email"'
      assert_includes html, "<textarea"
      number = html[/<input[^>]*type="number"[^>]*>/]

      assert_includes number, 'min="1"'
      assert_includes html, 'role="checkbox"'
      assert_includes html, 'data-orientation="horizontal"', "boolean = the horizontal Field"
      assert_includes html, 'data-slot="date-field"'
    end

    def test_errors_flow_into_the_quartet
      model = Account.new
      model.errors.add(:email, "is invalid")
      html = render_sf("<%= f.input :email %>", model: model)

      email = html[/<input[^>]*\[email\][^>]*>/]
      id = email[/id="([^"]+)"/, 1]

      assert_includes email, 'aria-invalid="true"'
      assert_includes email, %(aria-describedby="#{id}-error")
      assert_includes html, "Email is invalid"
    end

    def test_label_and_placeholder_options_pass_through
      html = render_sf("<%= f.input :name, label: \"Display name\", placeholder: \"Ada\" %>")

      assert_includes html, ">Display name</label>"
      assert_includes html, 'placeholder="Ada"'
    end

    def test_collection_inputs_render_poetry_pickers
      pairs = [["Starter", "starter"], ["Team", "team"]]
      html = render_sf("<%= f.input :plan, collection: plans %>" \
                       "<%= f.input :plan, as: :radio_buttons, collection: plans %>" \
                       "<%= f.input :plan, as: :check_boxes, collection: plans %>",
                       locals: { plans: pairs })

      assert_includes html, 'data-slot="select"'
      assert_includes html, 'role="radiogroup"'
      assert_includes html, 'data-controller="poetry--core--checkbox-group"'
      assert_includes html, "Starter"
    end

    def test_object_collections_use_the_detection_chain
      company = Struct.new(:id, :name)
      html = render_sf("<%= f.input :plan, collection: companies %>",
                       locals: { companies: [company.new(7, "Initech")] })

      assert_includes html, "Initech"
      assert_includes html, 'value="7"'
    end

    def test_datetime_falls_back_to_stock_simple_form
      klass = Class.new do
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :ships_at, :datetime

        def self.name = "Shipment"
      end
      html = render_sf("<%= f.input :ships_at %>", model: klass.new)

      assert_includes html, "select", "the stock datetime select trio renders (no poetry composite yet)"
    end

    def test_wrapper_contributes_nothing_but_display_contents
      html = render_sf("<%= f.input :name %>")

      assert_match(/class="contents [^"]*"/, html, "the passthrough wrapper is display:contents")
    end
  end
end
