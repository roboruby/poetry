# frozen_string_literal: true

require "test_helper"
require "tmpdir"
# The tests name the engine themselves, in whatever order they run.
require "herb"
require "herb/engine"
require "herb/engine/validators"

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

      # The engine raises parse and compile errors as syntax errors. The
      # gate lists them like any other finding instead of aborting the run.
      def test_a_template_that_does_not_parse_is_listed_not_raised
        message = TemplateCompile.compile(%(<div><%= body %>))

        assert_match(/closing tag/i, message)
      end

      # Nothing validates unless the gate asks: a block element inside a
      # paragraph parses and compiles, and only the nesting validator
      # refuses it.
      def test_invalid_nesting_refuses_to_compile
        message = TemplateCompile.compile(%(<p><div>text</div></p>))

        assert_match(/cannot be nested/i, message)
      end

      def test_the_gate_runs_every_validator_the_engine_ships
        TemplateCompile.compile("<div></div>")

        validators = TemplateCompile.send(:validators)

        assert_equal Herb::Engine::Validators::ALL.values, validators.map(&:class)
        assert(validators.all?(&:fatal?))
      end

      def test_an_older_herb_is_a_setup_error_not_a_finding
        refute TemplateCompile.send(:supported?, "0.10.4")
        assert TemplateCompile.send(:supported?, TemplateCompile::MINIMUM_HERB)
        assert TemplateCompile.send(:supported?, "0.12.0")
      end

      # The posture Rails checks an app's views in: the security validator
      # alone. A shape only the nesting validator refuses compiles there.
      def test_the_rails_posture_runs_the_security_validator_alone
        assert_nil TemplateCompile.compile(%(<p><div>text</div></p>), posture: :rails)
        assert_match(/attribute position/i,
                     TemplateCompile.compile(%(<div <%= attributes %>>Hello</div>), posture: :rails))

        validators = TemplateCompile.send(:validators, :rails)

        assert_equal [Herb::Engine::Validators::SecurityValidator], validators.map(&:class)
        assert(validators.all?(&:fatal?))
      end

      def test_a_posture_the_gate_does_not_know_is_refused
        error = assert_raises(ArgumentError) { TemplateCompile.compile("<div></div>", posture: :lenient) }

        assert_match(/strict, rails/, error.message)
      end

      # A failure carries the line the engine points at, whichever error
      # class it raised: a validator's or the parser's.
      def test_a_failure_carries_the_line_the_engine_points_at
        security = TemplateCompile.failure(%(<div>\n  <span data-<%= state %>=""></span>\n</div>\n))
        parse = TemplateCompile.failure(%(<div>\n\n  <p>Hello\n</div>\n))

        assert_equal 2, security.line
        assert_equal 3, parse.line
        assert_match(/closing tag/i, parse.message)
        assert_nil TemplateCompile.failure("<div></div>")
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
