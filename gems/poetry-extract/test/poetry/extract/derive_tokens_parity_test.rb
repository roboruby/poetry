# frozen_string_literal: true

require "test_helper"
require "json"

module Poetry
  module Extract
    # The oracle gate: the Ruby port must reproduce the UPSTREAM
    # derive-tokens outputs byte-for-byte on every fixture case.
    # Regenerating fixtures requires node (see oracle/run.mjs); this suite
    # does not.
    class DeriveTokensParityTest < Minitest::Test
      ORACLE = Pathname.new(__dir__).join("../../fixtures/oracle")
      INPUTS = JSON.parse(ORACLE.join("inputs.json").read)
      EXPECTED = JSON.parse(ORACLE.join("expected.json").read)

      INPUTS.each_key do |name|
        define_method("test_parity_#{name}_tailwind") do
          c = INPUTS.fetch(name)

          assert_equal EXPECTED.dig(name, "tailwind"),
                       DeriveTokens.derive_tailwind_theme(c["domain"], c["brand"], c["styleguide"])
        end

        define_method("test_parity_#{name}_css") do
          c = INPUTS.fetch(name)

          assert_equal EXPECTED.dig(name, "css"),
                       DeriveTokens.derive_css_variables(c["domain"], c["brand"], c["styleguide"])
        end
      end

      def test_the_oracle_covers_all_committed_cases
        assert_equal INPUTS.keys.sort, EXPECTED.keys.sort
        assert_operator INPUTS.size, :>=, 5
      end
    end
  end
end
