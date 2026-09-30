# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # No component the gem ships defines the reader Rails asks a component
    # for. NumberField keeps its format: option and answers Rails itself,
    # which is the shape the rule accepts.
    class RenderableReadersTest < Minitest::Test
      def test_no_component_declares_the_reader_rails_asks_for
        rule = Poetry::Core::Check::RenderableReaders.new
        findings = Dir.glob("app/components/**/*.rb", base: Poetry::Ui.root.to_s).sort.flat_map do |relative|
          rule.lint(File.read(Poetry::Ui.root.join(relative))).map { |finding| "#{relative}:#{finding.line}" }
        end

        assert_empty findings
      end
    end
  end
end
