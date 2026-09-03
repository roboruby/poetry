# frozen_string_literal: true

require "test_helper"

module Poetry
  module SimpleForm
    # Every poetry control is reachable by name through as:, the poetry:
    # hash carries poetry-only options, and the simple_form-only shapes
    # (grouped_select, time_zone, range, json) land on poetry components.
    class CustomInputsTest < ActionDispatch::IntegrationTest
      class Region
        attr_reader :name, :cities

        def initialize(name, cities)
          @name = name
          @cities = cities
        end
      end

      class Profile
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :volume, :integer
        attribute :code, :string
        attribute :secret, :string
        attribute :tags, :string
        attribute :zone, :string
        attribute :city, :string
        attribute :plan, :string
        attribute :notes, :string
        attribute :active, :boolean
        attribute :starts_on, :date
        attribute :settings, :string
      end

      REGIONS = [Region.new("Europe", %w[Berlin Lisbon]), Region.new("Asia", %w[Tokyo])].freeze

      def render_sf(erb, model: Profile.new, locals: {})
        ApplicationController.renderer.render(
          inline: "<%= simple_form_for(model, url: \"/profiles\") do |f| %>#{erb}<% end %>",
          locals: { model: model, **locals }, layout: false
        )
      end

      def component(html, key)
        Nokogiri::HTML5.fragment(html).at_css("[data-component=\"#{key}\"]")
      end

      def test_every_poetry_only_control_is_reachable_by_its_poetry_name
        {
          "<%= f.input :active, as: :switch %>" => "switch",
          "<%= f.input :volume, as: :slider %>" => "slider",
          "<%= f.input :code, as: :otp %>" => "input_otp",
          "<%= f.input :secret, as: :sensitive %>" => "sensitive_input",
          "<%= f.input :tags, as: :tag_group %>" => "tag_group",
          "<%= f.input :starts_on, as: :date_picker %>" => "date_picker",
          "<%= f.input :starts_on, as: :calendar %>" => "calendar",
          "<%= f.input :plan, as: :combobox, collection: %w[free pro] %>" => "combobox",
          "<%= f.input :city, as: :autocomplete, collection: %w[Berlin Lisbon] %>" => "autocomplete",
          "<%= f.input :plan, as: :native_select, collection: %w[free pro] %>" => "native_select"
        }.each do |erb, key|
          html = render_sf(erb)

          assert component(html, key), "#{erb} must render the #{key} component"
          assert_includes html, 'data-slot="field"', "#{erb} must render inside a poetry Field"
        end
      end

      def test_simple_form_shapes_land_on_poetry_controls
        assert component(render_sf("<%= f.input :volume, as: :range %>"), "slider"), ":range renders the Slider"
        assert component(render_sf("<%= f.input :settings, as: :json %>"), "textarea"), ":json renders the Textarea"
        assert component(render_sf("<%= f.input :code, as: :uuid %>"), "input"), ":uuid renders the Input"
      end

      def test_grouped_select_renders_labelled_groups_in_a_poetry_select
        html = render_sf("<%= f.input :city, as: :grouped_select, collection: regions, group_method: :cities %>",
                         locals: { regions: REGIONS })

        assert component(html, "select")
        %w[Europe Asia Berlin Tokyo].each { |text| assert_includes html, text }
      end

      def test_time_zone_renders_every_zone_with_the_priority_zones_first
        html = render_sf("<%= f.input :zone, as: :time_zone, priority: [\"Eastern Time (US & Canada)\"] %>")
        doc = Nokogiri::HTML5.fragment(html)

        assert component(html, "select")
        labels = doc.css('[data-component="select"] [data-value]').map { |node| node.text.strip }
        labels = doc.css('[data-component="select"] option').map { |node| node.text.strip } if labels.empty?
        assert_operator labels.size, :>, 100, "every ActiveSupport::TimeZone is offered"
        assert_match(/Eastern Time/, labels.reject(&:empty?).first.to_s, "the priority zone leads")
      end

      def test_the_poetry_hash_carries_poetry_only_options
        html = render_sf("<%= f.input :active, poetry: { switch: true } %>")

        assert component(html, "switch"), "poetry: { switch: true } turns the boolean into a Switch"

        html = render_sf("<%= f.input :code, as: :otp, poetry: { length: 4 } %>")

        assert_equal 4, Nokogiri::HTML5.fragment(html).css('[data-component="input_otp"] [data-slot="input-otp-slot"]').size,
                     "poetry: { length: 4 } reaches the InputOtp"
      end
    end
  end
end
