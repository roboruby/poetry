# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "rails/generators/generated_attribute"
require "generators/poetry/scaffold_templates/scaffold_templates_generator"

module Poetry
  # The scaffold-templates seam (, the external component set move done
  # the poetry way): `rails g scaffold` output that is poetry-composed AND
  # check-clean by construction - the expansion test below runs the same
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
      "email:string!", "website:string", "seats:integer!"
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

    def test_the_expanded_form_maps_column_names_to_input_types
      expanded = self.class.expanded("_form")

      assert_includes expanded, 'poetry_input(type: "email", name: form.field_name(:email)',
                      "an email column renders a type=email input (the a classes-only port heuristics)"
      assert_includes expanded, 'poetry_input(type: "url", name: form.field_name(:website)'
      assert_includes expanded, 'poetry_input(type: "text", name: form.field_name(:title)',
                      "names outside the heuristic lists stay text"
    end

    def test_the_expanded_form_carries_required_from_null_false
      expanded = self.class.expanded("_form")

      assert_includes expanded, 'label_text: "Email", required: true',
                      "a bang column (null: false) marks its Field required"
      assert_includes expanded, "value: post.seats, step: 1, required: true",
                      "composite fields carry required directly"
      refute_includes expanded, 'label_text: "Title", required: true',
                      "nullable columns stay unrequired"
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
