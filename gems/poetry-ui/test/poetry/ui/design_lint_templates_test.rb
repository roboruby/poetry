# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The gem's own AST-tier dogfood (N14 W3): every component template
    # lints clean against the design-slop rules. The DOM tier runs in
    # test/dommy_tier/design_dom_test.rb; the docs app lints its corpus in
    # its own suite. rake design:lint bundles both tiers on demand.
    class DesignLintTemplatesTest < Minitest::Test
      def test_component_templates_carry_no_design_slop
        findings = Dir[Poetry::Ui.root.join("app/components/**/*.html.erb").to_s].flat_map do |path|
          relative = Pathname.new(path).relative_path_from(Poetry::Ui.root).to_s
          Poetry::Core::DesignLint.lint(File.read(path), file: relative)
        end

        assert_empty findings.map(&:to_s)
      end
    end
  end
end
