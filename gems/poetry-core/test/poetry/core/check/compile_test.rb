# frozen_string_literal: true

require "test_helper"
require "tmpdir"
# The tests name the engine themselves, in whatever order they run, so it
# is loaded here and not by the first compile.
require "herb"
require "herb/engine"

module Poetry
  module Core
    module Check
      class CompileTest < Minitest::Test
        REFUSED = %(<div>\n  <span data-<%= state %>="" aria-hidden="true"></span>\n</div>\n)
        UNCLOSED = %(<div>\n  <p>Hello\n</div>\n)
        CLEAN = %(<div class="p-4" <%= tag.attributes(attrs) %>><%= body %></div>\n)

        def test_a_template_the_engine_refuses_is_one_finding_with_its_line
          finding = Compile.new.lint(REFUSED, filename: "app/components/pill_component.html.erb").first

          assert_equal "herb-compile", finding.rule
          assert_equal :warning, finding.severity
          assert_equal 2, finding.line
          assert_match(/\Adoes not compile under Herb, the compiler Rails 8\.2 renders with by default: /,
                       finding.message)
          assert_match(/attribute names/i, finding.message)
        end

        def test_the_message_carries_the_reason_without_the_path
          finding = Compile.new.lint(UNCLOSED, filename: "app/components/pill_component.html.erb").first

          refute_includes finding.message, "pill_component.html.erb"
          assert_match(/by default: Element `<p>`/, finding.message)
          assert_equal 2, finding.line
        end

        def test_a_clean_template_has_no_finding
          assert_empty Compile.new.lint(CLEAN, filename: "app/components/pill_component.html.erb")
        end

        # The posture is the one Rails checks views in: a shape only the
        # nesting validator refuses is not a finding here.
        def test_the_posture_is_the_one_rails_checks_views_in
          assert_empty Compile.new.lint(%(<p><div>text</div></p>\n), filename: "app/components/a.html.erb")
        end

        # An app that renders through Herb has the template fail where it
        # is used, so the finding is an error there.
        def test_an_app_that_renders_through_herb_has_an_error
          finding = Compile.new(rendering: true).lint(REFUSED, filename: "app/components/a.html.erb").first

          assert_equal :error, finding.severity
          assert_match(/\Adoes not compile under Herb, the compiler this app renders with: /, finding.message)
        end

        def test_scan_reads_the_html_templates_of_the_components_under_a_root
          Dir.mktmpdir("check-compile") do |root|
            write(root, "app/components/acme/pill_component.html.erb", REFUSED)
            write(root, "app/components/acme/note_component.html+phone.erb", UNCLOSED)
            write(root, "app/components/acme/card_component.html.erb", CLEAN)
            write(root, "app/components/acme/mail_component.text.erb", REFUSED)
            write(root, "app/views/pills/show.html.erb", REFUSED)

            findings = Compile.new.scan([root])
            names = findings.map { |finding| File.basename(finding.file) }

            assert_equal %w[note_component.html+phone.erb pill_component.html.erb], names
            assert(findings.all? { |finding| finding.file.start_with?(root) })
          end
        end

        # A gem's template is not the app's to fix, so the finding says
        # what is: the gem, or the herb the bundle resolves.
        def test_scan_says_a_shipped_template_is_fixed_by_the_gem_or_the_herb_version
          Dir.mktmpdir("check-compile") do |root|
            write(root, "app/components/acme/pill_component.html.erb", REFUSED)

            finding = Compile.new.scan([root]).first

            assert_match(/ - the template ships in a gem: update the gem, or hold herb at the version it was checked/,
                         finding.message)
            assert_includes finding.message, "herb #{Herb::VERSION}"
          end
        end

        def test_html_template_convention
          assert Compile.html_template?("app/components/acme/pill_component.html.erb")
          assert Compile.html_template?("/srv/app/app/components/pill_component.html+phone.erb")
          refute Compile.html_template?("app/components/acme/mail_component.text.erb")
          refute Compile.html_template?("app/components/acme/pill_component.erb")
          refute Compile.html_template?("app/views/pills/show.html.erb")
        end

        def test_an_older_herb_leaves_the_tier_unavailable_with_the_reason
          assert_nil Compile.unavailable
          with_herb_version("0.10.4") do
            assert_includes Compile.unavailable,
                            "needs herb #{TemplateCompile::MINIMUM_HERB} or newer, found 0.10.4"
          end
          assert_nil Compile.unavailable
        end

        # The app compiles with whatever its ERB handler names. Erubi is what
        # this suite renders with, so the switch is thrown for the test.
        def test_rendering_follows_the_implementation_the_handler_names
          refute_predicate Compile, :rendering?

          with_erb_implementation(Class.new(Herb::Engine)) do
            assert_predicate Compile, :rendering?
          end
          refute_predicate Compile, :rendering?
        end

        private

        def with_herb_version(version)
          real = Herb::VERSION
          Herb.send(:remove_const, :VERSION)
          Herb.const_set(:VERSION, version)
          yield
        ensure
          Herb.send(:remove_const, :VERSION)
          Herb.const_set(:VERSION, real)
        end

        def with_erb_implementation(implementation)
          handler = ActionView::Template::Handlers::ERB
          real = handler.erb_implementation
          handler.erb_implementation = implementation
          yield
        ensure
          handler.erb_implementation = real
        end

        def write(root, relative, source)
          path = File.join(root, relative)
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, source)
        end
      end
    end
  end
end
