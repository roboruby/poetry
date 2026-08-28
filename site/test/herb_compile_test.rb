# frozen_string_literal: true

require "test_helper"
require "herb"

# The Herb compile dogfood: every view, layout and example partial in this
# app compiles under Herb::Engine - the compiler Rails routes templates
# through for hosts on the Herb ERB implementation - so the docs site is
# the standing proof that a poetry-built app is Herb-ready. The engine's
# validators reject shapes Erubi renders happily (ERB output in an
# attribute name, bare output in attribute position, a nested ERB tag
# inside a code-sample heredoc), which is exactly why this runs.
class HerbCompileTest < ActiveSupport::TestCase
  test "every app template compiles under Herb::Engine" do
    templates = Dir.glob("app/**/*.erb", base: Rails.root.to_s).sort
    assert_operator templates.size, :>, 100, "expected the docs corpus, found #{templates.size} templates"

    failures = templates.filter_map do |relative|
      Herb::Engine.new(Rails.root.join(relative).read, filename: relative)
      nil
    rescue StandardError => e
      "#{relative}: #{e.message}"
    end

    assert_empty failures, "templates that refuse to compile under Herb::Engine:\n#{failures.join("\n")}"
  end
end
