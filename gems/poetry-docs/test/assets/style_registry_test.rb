require "test_helper"

# The nine-theme style registry (tailwind/styles/) is GENERATED
# from the sibling gems by script/build_style_registry.rb and can silently
# go stale when a gem's theme layer grows (that's how the syntax
# palette went missing and code samples rendered unhighlighted). These
# assertions pin the palette's presence per theme; on failure, re-run
# script/build_style_registry.rb.
class StyleRegistryTest < ActiveSupport::TestCase
  THEMES = %w[default vega nova mira rhea maia luma lyra sera].freeze
  SYNTAX_VARS = %w[keyword constant string entity markup function comment].freeze

  THEMES.each do |theme|
    test "style-#{theme} defines the full syntax palette" do
      fragment = Poetry::Docs.root.join("tailwind/styles/style-#{theme}.css").read

      SYNTAX_VARS.each do |var|
        assert_includes fragment, "[--syntax-#{var}:",
          "style-#{theme}.css is missing --syntax-#{var} — stale registry, re-run script/build_style_registry.rb"
        assert_includes fragment, "dark:[--syntax-#{var}:",
          "style-#{theme}.css is missing the dark --syntax-#{var} — stale registry, re-run script/build_style_registry.rb"
      end
    end
  end

  test "compiled tailwind css carries the syntax variable definitions" do
    compiled = Poetry::Docs.root.join("app/assets/builds/poetry_docs.css").read

    assert_includes compiled, "--syntax-keyword:",
      "builds/poetry_docs.css has no syntax palette - run rake poetry_docs:css after regenerating the registry"
  end
end
