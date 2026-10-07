# frozen_string_literal: true

require "test_helper"

class StylesheetsTest < Minitest::Test
  Stylesheets = Poetry::JumpstartPro::Stylesheets

  def test_the_forms_plugin_moves_to_the_class_strategy
    css = Stylesheets.tailwind_entry(%(@plugin "@tailwindcss/forms";\n))

    assert_includes css, %(@plugin "@tailwindcss/forms" {\n  strategy: class;\n})
  end

  def test_an_already_configured_forms_plugin_is_left_alone
    css = %(@plugin "@tailwindcss/forms" {\n  strategy: base;\n}\n)

    assert_equal css, Stylesheets.tailwind_entry(css)
  end

  def test_the_primary_mapping_becomes_a_comment
    css = Stylesheets.tailwind_entry("@theme {\n  --color-primary: var(--bg-primary);\n}\n")

    assert_includes css, "  /* --color-primary comes from Poetry's tokens"
    refute_includes css, "--color-primary: var"
  end

  def test_a_theme_background_becomes_a_comment
    css = Stylesheets.theme(".dark {\n  --background: var(--color-gray-900);\n  --divider-color: red;\n}\n")

    assert_includes css, "/* --background comes from Poetry's tokens"
    assert_includes css, "--divider-color: red;"
  end

  def test_base_drops_the_bare_global_rules_and_keeps_the_rest
    css = "body {\n  margin: 0;\n}\n\na {\n  color: red;\n\n  &:hover {\n    color: blue;\n  }\n}\n\n" \
          "ol {\n  list-style-type: decimal;\n}\n\nhr {\n  border-color: red;\n}\n\n.table a {\n  color: red;\n}\n"
    out = Stylesheets.base(css)

    assert out.start_with?(Stylesheets::BASE_NOTE)
    assert_includes out, "body {"
    assert_includes out, "hr {"
    assert_includes out, ".table a {"
    refute_match(/^a \{/, out)
    refute_match(/^ol \{/, out)
  end

  def test_base_keeps_a_supports_block_with_other_rules
    css = "@supports (display: grid) {\n  a {\n    color: red;\n  }\n  .grid {\n    display: grid;\n  }\n}\n"

    assert_equal css, Stylesheets.base(css)
  end

  def test_braces_in_comments_and_strings_do_not_confuse_the_scanner
    css = "/* a { not a rule } */\n.icon::before {\n  content: \"}\";\n}\n\nul {\n  margin: 0;\n}\n"
    out = Stylesheets.base(css)

    assert_includes out, "content: \"}\";"
    assert_includes out, "/* a { not a rule } */"
    refute_match(/^ul \{/, out)
  end

  def test_bare_typography_elements_skip_poetry_slots
    css = "h1, .h1 {\n  font-size: 3rem;\n}\n\ncode {\n  padding: 0;\n}\n\npre code {\n  display: block;\n}\n\n" \
          "kbd {\n  font-size: 1rem;\n}\n\n.link {\n  color: red;\n}\n"
    out = Stylesheets.typography(css)

    assert_includes out, "h1:not([data-slot]), .h1 {"
    assert_includes out, "code:not([data-slot]) {"
    assert_includes out, "pre code:not([data-slot]) {"
    assert_includes out, "kbd:not([data-slot]) {"
    assert_includes out, ".link {"
    assert_equal out, Stylesheets.typography(out)
  end

  def test_every_edit_is_idempotent
    entry = %(@plugin "@tailwindcss/forms";\n@theme {\n  --color-primary: var(--bg-primary);\n}\n)
    base = "a {\n  color: red;\n}\n\nul {\n  margin: 0;\n}\n\nbody {\n  margin: 0;\n}\n"
    [[:tailwind_entry, entry], [:theme, "--background: white;\n"], [:base, base]].each do |edit, css|
      once = Stylesheets.public_send(edit, css)

      assert_equal once, Stylesheets.public_send(edit, once), "#{edit} is not idempotent"
    end
  end
end
