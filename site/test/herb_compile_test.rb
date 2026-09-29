# frozen_string_literal: true

require "test_helper"

# The Herb compile dogfood: every view, layout and example partial in this
# app compiles under Herb::Engine - the compiler Rails routes HTML templates
# through under its 8.2 framework defaults - so the docs site is the
# standing proof that a poetry-built app is Herb-ready. It runs the gems'
# own gate, Poetry::Core::TemplateCompile, so the site and the gems hold
# one posture: every validator the engine ships, each one fatal. They
# reject shapes Erubi renders happily (ERB output in an attribute name,
# bare output in attribute position, a nested ERB tag inside a code-sample
# heredoc), which is exactly why this runs.
class HerbCompileTest < ActiveSupport::TestCase
  test "every app template compiles under Herb::Engine" do
    result = Poetry::Core::TemplateCompile.check(root: Rails.root, globs: [ "app/**/*.erb" ])
    failures = result.errors.map(&:to_s)
    total = result.compiled + failures.size

    assert_operator total, :>, 100, "expected the docs corpus, found #{total} templates"
    assert_empty failures, "templates that refuse to compile under Herb::Engine:\n#{failures.join("\n")}"
  end
end
