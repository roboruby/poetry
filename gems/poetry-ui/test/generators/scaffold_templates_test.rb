# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "rails/generators/generated_attribute"
require "generators/poetry/scaffold_templates/scaffold_templates_generator"

module Poetry
  # The scaffold-templates seam: `rails g scaffold` output that is
  # poetry-composed AND check-clean by construction - the expansion test
  # below runs the same
  # linter CI runs over the docs corpus against the templates' expanded
  # output, so a template that drifts from the component contracts fails
  # here before any host app generates a broken view.
  class ScaffoldTemplatesGeneratorTest < Rails::Generators::TestCase
    tests ScaffoldTemplatesGenerator
    destination File.expand_path("../tmp/scaffold_templates", __dir__)
    setup :prepare_destination

    VIEWS = %w[index show new edit _form partial].freeze

    def test_copies_the_view_and_controller_templates
      run_generator

      VIEWS.each do |name|
        assert_file "lib/templates/erb/scaffold/#{name}.html.erb.tt"
      end
      assert_file "lib/templates/rails/scaffold_controller/controller.rb.tt"
    end

    def test_skip_controller_leaves_the_stock_controller_template
      run_generator %w[--skip-controller]

      assert_file "lib/templates/erb/scaffold/index.html.erb.tt"
      assert_no_file "lib/templates/rails/scaffold_controller/controller.rb.tt"
    end

    # --- expansion: the templates produce check-clean poetry ERB ----------

    # A generator-time binding double carrying what the erb scaffold
    # generator provides; helpers return the literal Ruby the template
    # splices into the generated view.
    class TemplateContext
      def initialize(attributes)
        @attributes = attributes
      end

      attr_reader :attributes

      def human_name = "Post"
      def plural_table_name = "posts"
      def singular_table_name = "post"
      def singular_name = "post"
      def model_resource_name = "post"
      def new_helper(type: :url) = type == :path ? "new_post_path" : "new_post_url"
      def index_helper(type: :url) = type == :path ? "posts_path" : "posts_url"
      def edit_helper(type: :url) = type == :path ? "edit_post_path(@post)" : "edit_post_url(@post)"
      def show_helper(type: :url) = type == :path ? "post_path(@post)" : "post_url(@post)"
      def template_binding = binding
    end

    ATTRIBUTES = [
      "title:string", "body:text", "price:decimal", "quantity:integer",
      "published:boolean", "published_on:date", "starts_at:datetime",
      "password:digest", "photo:attachment", "documents:attachments",
      "email:string!", "website:string", "seats:integer!", "summary:rich_text"
    ].freeze

    def self.expanded(name)
      source = File.read(File.expand_path(
                           "../../lib/generators/poetry/scaffold_templates/templates/#{name}.html.erb.tt", __dir__
                         ))
      context = TemplateContext.new(
        ATTRIBUTES.map { |a| Rails::Generators::GeneratedAttribute.parse(a) }
      )
      ERB.new(source, trim_mode: "-").result(context.template_binding)
    end

    def catalog
      @catalog ||= Poetry::Core::Check::Catalog.from_registry(
        Poetry::Ui.root, helpers: Poetry::Ui.helper_names
      )
    end

    VIEWS.each do |name|
      define_method("test_the_expanded_#{name.delete_prefix("_")}_template_is_check_clean") do
        expanded = self.class.expanded(name)
        findings = Poetry::Core::Check.lint(expanded, catalog: catalog)
        errors = findings.select { |f| f.severity == :error }

        assert_empty errors, "#{name}: #{errors.map { |f| "#{f.rule}: #{f.message}" }.join("; ")}\n---\n#{expanded}"
      end
    end

    def test_the_expanded_index_wires_state_sorting_to_real_columns_only
      expanded = self.class.expanded("index")

      assert_includes expanded, 'with_column("Title", key: :title, sortable: true)'
      assert_includes expanded, 'with_column("Photo")', "attachments are not sortable columns"
      refute_includes expanded, "password", "password digests never render in the table"
    end

    # The form is the builder's: one f.input per attribute, the control
    # inferred at render time; the template adds only what the generator
    # knows and the model cannot say.
    def test_the_expanded_form_is_one_builder_call_per_attribute
      expanded = self.class.expanded("_form")

      assert_includes expanded, "form_with(model: post, builder: Poetry::Ui::FormBuilder"
      assert_includes expanded, "<%= form.input :title %>", "a plain column carries nothing - the builder infers"
      assert_includes expanded, "<%= form.input :email, required: true %>", "null: false -> required"
      assert_includes expanded, "<%= form.input :seats, required: true %>"
      assert_includes expanded, "<%= form.input :summary, as: :text %>", "rich_text is not a column: as: :text"
      assert_includes expanded, "<%= form.input :documents, multiple: true %>", "has_many_attached: multiple"
      assert_includes expanded, "<%= form.input :photo %>", "has_one_attached: inferred"
      assert_includes expanded, "<%= form.input :password %>"
      assert_includes expanded, "<%= form.input :password_confirmation %>"
      assert_includes expanded, "<%= form.submit %>"
      refute_includes expanded, "poetry_field(", "no hand-wired Field remains"
      refute_includes expanded, "poetry_input(", "no hand-wired Input remains"
    end

    # The generated form, rendered: an ActiveModel post with the scaffold's
    # attribute shapes (the dummy draws resources :posts for the URLs).
    class ScaffoldPost
      include ActiveModel::Model
      include ActiveModel::Attributes

      def self.model_name = ActiveModel::Name.new(self, nil, "Post")

      # ActiveModel registers no :text type; the builder reads the type's
      # name, so a text column is an ActiveRecord-shaped :text here.
      class TextType < ActiveModel::Type::String
        def type = :text
      end

      attribute :title, :string
      attribute :body, TextType.new
      attribute :price, :decimal
      attribute :quantity, :integer
      attribute :published, :boolean
      attribute :published_on, :date
      attribute :starts_at, :datetime
      attribute :email, :string
      attribute :website, :string
      attribute :seats, :integer
      attr_accessor :password, :password_confirmation, :photo, :documents, :summary

      def photo_attachment = nil
      def documents_attachments = []
      def persisted? = false
    end

    def test_the_expanded_form_renders_every_attribute_through_the_builder
      html = ApplicationController.renderer.render(inline: self.class.expanded("_form"),
                                                   locals: { post: ScaffoldPost.new }, layout: false)
      doc = Nokogiri::HTML5.fragment(html)
      controls = doc.css("input[name], textarea[name]").to_h { |el| [el["name"], el] }

      assert_equal "url", controls.fetch("post[website]")["type"]
      assert_equal "email", controls.fetch("post[email]")["type"]
      assert_equal "true", controls.fetch("post[email]")["aria-required"], "required: true rides through"
      assert_equal "password", controls.fetch("post[password]")["type"]
      assert_equal "password", controls.fetch("post[password_confirmation]")["type"]
      assert_equal "textarea", controls.fetch("post[body]").name, "a text column is a textarea"
      assert_equal "textarea", controls.fetch("post[summary]").name, "rich_text is a textarea"
      assert_equal "checkbox", controls.fetch("post[published]")["type"]
      assert_equal "date", controls.fetch("post[published_on]")["type"]
      assert_equal "file", controls.fetch("post[photo]")["type"]
      assert controls.fetch("post[documents][]")["multiple"], "has_many_attached: multiple"
      assert_equal 15, doc.css("[data-slot=field-label]").size, "one Field per attribute (digest = two)"
      assert_equal "Create Post", doc.at_css("button[type=submit]").text.strip
      assert_empty doc.css("[data-slot=alert]"), "no errors, no summary"
    end

    def test_the_controller_template_whitelists_only_real_columns
      source = File.read(File.expand_path(
                           "../../lib/generators/poetry/scaffold_templates/templates/controller.rb.tt", __dir__
                         ))

      assert_includes source, "reject { |a| a.attachment? || a.attachments? || a.rich_text? || a.password_digest? }",
                      "the sortable whitelist and the index view's sortable columns must derive identically"
      assert_includes source, "State.from_params"
    end
  end
end
