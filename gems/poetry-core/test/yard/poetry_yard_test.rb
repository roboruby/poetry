# frozen_string_literal: true

require "test_helper"
require "yard"

load File.expand_path("../../yard/poetry_yard.rb", __dir__)

module Poetry
  module Core
    # The doc-build handler kit (yard/poetry_yard.rb): the prose a
    # declaration's doc: string carries reaches the registry as Ruby reads
    # the literal, not as its source text.
    class PoetryYardTest < Minitest::Test
      def setup
        YARD::Registry.clear
      end

      def test_an_escaped_quote_in_a_doc_string_is_a_quote_in_the_registry
        YARD.parse_string(<<~'SOURCE')
          module Poetry
            class Probe
              option :ratio, :string, doc: "A CSS <ratio>: \"16/9\", \"1\" - kept a string so " \
                                           "the fraction survives into the --ratio property."
            end
          end
        SOURCE

        docstring = YARD::Registry.at("Poetry::Probe#ratio").docstring.to_s

        assert_includes docstring, %(A CSS <ratio>: "16/9", "1" - kept a string so the fraction survives)
        refute_includes docstring, "\\"
      end

      def test_a_doc_string_without_escapes_is_unchanged
        YARD.parse_string(<<~SOURCE)
          module Poetry
            class Probe
              option :size, :symbol, default: :md, doc: "The control's height step (sm, md, lg)."
            end
          end
        SOURCE

        docstring = YARD::Registry.at("Poetry::Probe#size").docstring

        assert_includes docstring.to_s, "The control's height step (sm, md, lg)."
        assert_includes docstring.tag(:return).text, "defaults to `:md`"
      end
    end
  end
end
