# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Check
      class RenderableReadersTest < Minitest::Test
        def test_an_option_named_format_is_flagged_with_the_line_and_the_way_out
          finding = lint(<<~RUBY).first
            module Price
              class Component < Poetry::Core::Component
                option :name, :string
                option :format, ActiveModel::Type::Value.new, doc: "Intl.NumberFormatOptions"
              end
            end
          RUBY

          assert_equal "renderable-reader", finding.rule
          assert_equal :warning, finding.severity
          assert_equal 4, finding.line
          assert_match(/\Aoption :format defines the reader Rails asks a component for the format of its template/,
                       finding.message)
          assert_match(/Invalid formats/, finding.message)
          assert_match(/define_method\(:format\) \{ nil \}/, finding.message)
        end

        def test_every_declaration_that_defines_the_reader_is_flagged
          source = <<~RUBY
            class A < Poetry::Core::Component
              style :format, %i[long short]
            end
            class B < Poetry::Core::Component
              renders_one :format
            end
            class C < Poetry::Core::Component
              option "format", :string
            end
          RUBY

          findings = lint(source)
          openings = findings.map { |finding| finding.message[/\A\w+ :format/] }

          assert_equal [2, 5, 8], findings.map(&:line)
          assert_equal ["style :format", "renders_one :format", "option :format"], openings
        end

        def test_a_class_that_answers_rails_itself_is_left_alone
          assert_empty lint(<<~RUBY)
            class Component < Poetry::Core::Component
              option :format, ActiveModel::Type::Value.new

              def number_format = attribute("format")

              define_method(:format) { nil }
            end
          RUBY
          assert_empty lint(<<~RUBY)
            class Component < Poetry::Core::Component
              option :format, :string

              def format
                nil
              end
            end
          RUBY
        end

        def test_other_names_and_other_classes_are_left_alone
          assert_empty lint(<<~RUBY)
            class Component < Poetry::Core::Component
              option :number_format, :string
              option :formats, :string
              renders_many :formats
            end
            class Report
              def format = :pdf
            end
          RUBY
        end

        def test_the_severity_is_the_one_given
          source = "class Component < Poetry::Core::Component\n  option :format, :string\nend\n"
          finding = RenderableReaders.new(severity: :error).lint(source).first

          assert_equal :error, finding.severity
        end

        def test_source_that_does_not_parse_is_not_a_finding
          assert_empty lint("class Component < Poetry::Core::Component\n  option :format\n")
        end

        private

        def lint(source)
          RenderableReaders.new.lint(source)
        end
      end
    end
  end
end
