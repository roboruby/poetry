# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Poetry
  module Core
    class TemplateCompileTest < Minitest::Test
      def test_a_clean_template_compiles
        assert_nil TemplateCompile.compile(<<~ERB)
          <div class="p-4" <%= tag.attributes(attrs) %>>
            <% if checked %>data-checked=""<% end %>
            <option value="<%= value %>" <% if selected %>selected<% end %>><%= label %></option>
          </div>
        ERB
      end

      # The two shapes Erubi renders happily and Herb::Engine refuses:
      # ERB output in an attribute NAME, and bare output in attribute
      # position. Both are compile errors, not parse errors.
      def test_erb_output_in_an_attribute_name_refuses_to_compile
        message = TemplateCompile.compile(%(<span data-<%= state %>="" aria-hidden="true"></span>))

        assert_match(/attribute name/i, message)
      end

      def test_bare_output_in_attribute_position_refuses_to_compile
        message = TemplateCompile.compile(%(<option value="x" <%= "selected" if current %>>x</option>))

        refute_nil message
      end

      # tag.attributes is understood by the compiler, but only as the LAST
      # thing in the tag: followed by another attribute it reads as an
      # attribute name.
      def test_tag_attributes_mid_tag_refuses_to_compile
        assert_nil TemplateCompile.compile(%(<div data-slot="x" <%= tag.attributes(attrs) %>></div>))
        refute_nil TemplateCompile.compile(%(<div <%= tag.attributes(attrs) %> data-slot="x"></div>))
      end

      def test_check_counts_compiled_templates_and_names_the_failures
        Dir.mktmpdir("poetry-herb") do |root|
          FileUtils.mkdir_p(File.join(root, "app/components/one"))
          File.write(File.join(root, "app/components/one/good.html.erb"), "<div><%= body %></div>\n")
          File.write(File.join(root, "app/components/one/bad.html.erb"), %(<span data-<%= state %>=""></span>\n))

          result = TemplateCompile.check(root: root)

          assert_equal 1, result.compiled
          assert_equal ["app/components/one/bad.html.erb"], result.errors.map(&:path)
          assert_match(/bad\.html\.erb: /, result.errors.first.to_s)
        end
      end

      # The gate itself: every template poetry-core ships compiles.
      def test_gem_templates_compile_clean
        result = TemplateCompile.check(root: Poetry::Core.root)

        assert_empty result.errors.map(&:to_s)
        assert_operator result.compiled, :>=, 1
      end
    end
  end
end
