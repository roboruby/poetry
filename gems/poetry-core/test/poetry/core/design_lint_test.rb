# frozen_string_literal: true

require "test_helper"
require "nokogiri"

module Poetry
  module Core
    # Every DesignLint rule proven both ways: the red source trips exactly
    # this rule, the green cousin stays silent (DoD: green+red per rule).
    class DesignLintTest < Minitest::Test
      def rules_hit(source)
        DesignLint.lint(source).map(&:rule).uniq.sort
      end

      def assert_red_green(rule, red:, green:)
        assert_includes rules_hit(red), rule, "red fixture must trip #{rule}"
        refute_includes rules_hit(green), rule, "green fixture must not trip #{rule}"
      end

      # --- AST tier ------------------------------------------------------

      def test_card_in_card_on_helper_calls
        assert_red_green("card-in-card",
                         red: "<%= poetry_card do %><%= poetry_card do %>inner<% end %><% end %>",
                         green: "<%= poetry_card do %>body<% end %><%= poetry_card do %>peer<% end %>")
      end

      def test_card_in_card_on_rendered_markup
        red = <<~HTML
          <div data-slot="card"><div class="border rounded-xl bg-card">inner</div></div>
        HTML
        green = %(<div data-slot="card"><div class="p-4">plain body</div></div>)

        assert_red_green("card-in-card", red: red, green: green)
      end

      def test_icon_tile_over_heading
        red = <<~HTML
          <div class="rounded-lg bg-primary/10 p-3"><svg viewBox="0 0 24 24"></svg></div>
          <h3 class="text-lg">Fast by default</h3>
        HTML
        green = <<~HTML
          <h3 class="text-lg"><svg viewBox="0 0 24 24"></svg> Fast by default</h3>
        HTML

        assert_red_green("icon-tile-over-heading", red: red, green: green)
      end

      def test_wall_of_cards
        card = %(<div class="border rounded-xl bg-card p-4">x</div>)
        red = "<section>#{card * 4}</section>"
        green = "<section>#{card * 2}<ul><li>a</li><li>b</li></ul></section>"

        assert_red_green("wall-of-cards", red: red, green: green)
      end

      def test_off_scale_arbitrary_values
        assert_red_green("off-scale-arbitrary",
                         red: %(<div class="p-[13px] mt-2">x</div>),
                         green: %(<div class="p-3.5 mt-2 text-[0.875rem] w-[calc(100%-2rem)]">x</div>))
      end

      def test_off_scale_message_names_the_nearest_steps
        finding = DesignLint.lint(%(<div class="p-[13px]">x</div>)).first

        assert_match(/p-3 = 12px/, finding.message)
        assert_match(/p-3\.5 = 14px/, finding.message)
      end

      def test_exact_scale_values_get_the_scale_spelling
        finding = DesignLint.lint(%(<div class="w-[200px]">x</div>)).first

        assert_match(/is the scale value w-50 - use the scale spelling/, finding.message)
      end

      def test_gradient_off_token
        assert_red_green("gradient-off-token",
                         red: %(<div class="bg-gradient-to-r from-purple-500 to-blue-500">x</div>),
                         green: %(<div class="bg-primary text-primary-foreground">x</div>))
      end

      def test_heading_skip
        assert_red_green("heading-skip",
                         red: "<h1>Title</h1><h3>Skipped</h3>",
                         green: "<h1>Title</h1><h2>Section</h2><h3>Sub</h3>")
      end

      def test_center_everything
        centered = %(<p class="text-center">x</p>)

        assert_red_green("center-everything",
                         red: "<div>#{centered * 3}</div>",
                         green: "<div class='text-center'><h1>Hero</h1>#{centered}</div>")
      end

      def test_shadow_stack
        assert_red_green("shadow-stack",
                         red: %(<div class="shadow-lg"><div class="shadow-sm">x</div></div>),
                         green: %(<div class="shadow-lg"><div class="shadow-none border">x</div></div>))
      end

      def test_findings_carry_file_line_and_fix_naming_messages
        findings = DesignLint.lint("<h1>a</h1>\n<h4>b</h4>", file: "app/views/home.html.erb")
        finding = findings.first

        assert_equal "app/views/home.html.erb", finding.file
        assert_equal 2, finding.line
        assert_equal :warning, finding.severity
        assert_match(/insert h2 or demote/, finding.message)
      end

      # --- DOM tier ------------------------------------------------------

      def dom_lint(html, styles_by_selector, context: {})
        doc = Nokogiri::HTML5.fragment(html)
        styles = lambda do |el|
          styles_by_selector.find { |selector, _| el.matches?(selector) }&.last ||
            { "font-size" => "16px", "background-color" => "rgba(0, 0, 0, 0)" }
        end
        DesignLint.lint_dom(doc: doc, styles: styles, context: context).map(&:rule)
      end

      def test_type_scale_monotony
        html = "<main>#{"<p>copy</p>" * 5}<h1>title</h1></main>"
        flat = { "p, h1, main" => { "font-size" => "16px" } }
        varied = { "h1" => { "font-size" => "30px" }, "p, main" => { "font-size" => "16px" } }

        assert_includes dom_lint(html, flat), "type-scale-monotony"
        refute_includes dom_lint(html, varied), "type-scale-monotony"
      end

      def test_adjacent_same_surface
        html = %(<div class="wrap"><section class="a">x</section><section class="b">y</section></div>)
        same = { "section" => { "background-color" => "oklch(1 0 0)" },
                 ".wrap" => { "gap" => "0px", "background-color" => "rgba(0,0,0,0)" } }
        separated = { "section.a" => { "background-color" => "oklch(1 0 0)", "border-width" => "1px" },
                      "section.b" => { "background-color" => "oklch(1 0 0)" },
                      ".wrap" => { "gap" => "0px", "background-color" => "rgba(0,0,0,0)" } }

        assert_includes dom_lint(html, same), "adjacent-same-surface"
        refute_includes dom_lint(html, separated), "adjacent-same-surface"
      end

      def test_contrast_adjacent_surfaces
        html = %(<div class="wrap"><section class="a">x</section><section class="b">y</section></div>)
        near = { "section.a" => { "background-color" => "oklch(1 0 0)" },
                 "section.b" => { "background-color" => "oklch(0.99 0 0)" },
                 ".wrap" => { "gap" => "0px", "background-color" => "rgba(0,0,0,0)" } }
        distinct = { "section.a" => { "background-color" => "oklch(1 0 0)" },
                     "section.b" => { "background-color" => "oklch(0.85 0 0)" },
                     ".wrap" => { "gap" => "0px", "background-color" => "rgba(0,0,0,0)" } }

        assert_includes dom_lint(html, near), "contrast-adjacent"
        refute_includes dom_lint(html, distinct), "contrast-adjacent"
      end

      def test_stock_theme_nudge
        hit = dom_lint("<div></div>", {}, context: { design_md_present: true, overrides_present: false })
        applied = dom_lint("<div></div>", {}, context: { design_md_present: true, overrides_present: true })

        assert_includes hit, "stock-theme-nudge"
        refute_includes applied, "stock-theme-nudge"
      end

      def test_rules_registry_documents_every_rule_with_provenance
        assert_equal 12, DesignLint::RULES.size
        DesignLint::RULES.each do |id, (tier, provenance)|
          assert_includes %i[ast dom], tier, id
          assert_match(/the design-rule analogue|the slop-gate analogue|the judged-run calibration/, provenance, "#{id} must cite its analogue")
        end
      end
    end
  end
end
