# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # No component the gem ships defines the reader Rails asks a component
    # for. The rule reads every class the gem ships.
    class RenderableReadersTest < Minitest::Test
      def test_no_component_declares_the_reader_rails_asks_for
        rule = Poetry::Core::Check::RenderableReaders.new
        findings = Dir.glob("app/components/**/*.rb", base: Poetry::Charts.root.to_s).sort.flat_map do |relative|
          rule.lint(File.read(Poetry::Charts.root.join(relative))).map { |finding| "#{relative}:#{finding.line}" }
        end

        assert_empty findings
      end
    end
  end
end
