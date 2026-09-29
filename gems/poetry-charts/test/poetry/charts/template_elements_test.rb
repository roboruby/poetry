# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # Every template this gem ships builds its elements through element_tag
    # and hands tag.attributes its hash as an argument: the strict form of
    # the element rule `poetry check` holds a host's component templates to.
    # A host that compiles with Herb's slots resolves Action View's own tag
    # helpers ahead of the render, and what it cannot read it drops.
    class TemplateElementsTest < Minitest::Test
      GLOBS = ["app/**/*.erb", "lib/generators/**/templates/**/*.erb", "lib/generators/**/templates/**/*.erb.tt"].freeze

      def test_no_template_calls_an_action_view_tag_helper
        linter = Poetry::Core::Check::TagHelpers.new(strict: true)
        root = Poetry::Charts.root
        templates = GLOBS.flat_map { |glob| Dir.glob(glob, base: root.to_s) }.uniq.sort

        findings = templates.flat_map do |relative|
          linter.lint(root.join(relative).read).map { |finding| "#{relative}:#{finding.line}: #{finding.message}" }
        end

        refute_empty templates
        assert_empty findings, "templates that build an element through a tag helper:\n#{findings.join("\n")}"
      end
    end
  end
end
