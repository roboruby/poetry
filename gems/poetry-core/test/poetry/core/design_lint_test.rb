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

      def test_centered_cells_and_controls_never_count
        # A calendar month: dozens of centered gridcells are correct design.
        cell = %(<div role="gridcell" class="text-center"><button class="text-center">1</button></div>)
        green = %(<div role="grid">#{cell * 40}</div>)

        refute_includes rules_hit(green), "center-everything"
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

      def test_typeset_prose_is_exempt_from_type_scale_monotony
        # Typeset sizes prose via em-derived nested:where rules
        # the static renderer cannot compute - bare elements at one computed
        # size are the pattern there, not the slop.
        prose = "#{"<p>copy</p>" * 5}<h1>title</h1>"
        html = %(<main><div class="typeset typeset-docs">#{prose}</div></main>)
        flat = { "p, h1, main, div" => { "font-size" => "16px" } }

        refute_includes dom_lint(html, flat), "type-scale-monotony"
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

      def test_mixed_status_weight_in_one_table
        red = <<~HTML
          <table>
            <tr><td><span data-slot="badge" data-variant="success">Fulfilled</span></td></tr>
            <tr><td><span data-slot="badge" data-variant="destructive">Overdue</span></td></tr>
          </table>
        HTML
        green = <<~HTML
          <table>
            <tr><td><span data-slot="badge" data-variant="success">Fulfilled</span></td></tr>
            <tr><td><span data-slot="badge" data-variant="warning">Processing</span></td></tr>
            <tr><td><span data-slot="badge" data-variant="outline">Refunded</span></td></tr>
          </table>
        HTML

        assert_red_green("mixed-status-weight", red: red, green: green)
      end

      def test_mixed_status_weight_scopes_per_table
        separate = <<~HTML
          <table><tr><td><span data-slot="badge" data-variant="destructive">Failed</span></td></tr></table>
          <table><tr><td><span data-slot="badge" data-variant="success">Paid</span></td></tr></table>
        HTML

        refute_includes rules_hit(separate), "mixed-status-weight",
                        "solid and soft in DIFFERENT tables are two consistent sets"
      end

      # --- tranche 2: copy/composition tells --------------------

      def test_em_dash_overuse
        prose = "We build tools — fast ones — for teams — everywhere — always — now. " * 2
        red = "<p>#{prose}</p>"
        green = "<p>We build fast tools for teams. One aside — that is fine. #{"filler words " * 10}</p>"

        assert_red_green("em-dash-overuse", red: red, green: green)
      end

      def test_em_dash_ignores_code_samples
        code = "<pre>#{"a — b — c — d — e — f\n" * 3}</pre><p>#{"plain copy here " * 8}</p>"

        refute_includes rules_hit(code), "em-dash-overuse", "em dashes in code are content, not prose"
      end

      def test_marketing_buzzword
        red = "<p>Streamline your workflow with our enterprise-grade, all-in-one platform " \
              "and take shipping to the next level. #{"more words " * 8}</p>"
        green = "<p>Renders components on the server and checks the result. #{"plain detail " * 10}</p>"

        assert_red_green("marketing-buzzword", red: red, green: green)
      end

      def test_aphoristic_cadence
        red = "<p>Not a framework. A contract. Not a wrapper. A rewrite. " \
              "No config. Just results. #{"context words " * 10}</p>"
        green = "<p>It is not a framework replacement; it layers on top of Rails. #{"detail " * 12}</p>"

        assert_red_green("aphoristic-cadence", red: red, green: green)
      end

      def test_numbered_section_markers
        red = "<div><span>01</span> Plan <span>02</span> Build <span>03</span> Ship " \
              "#{"filler copy words here " * 5}</div>"
        green = "<p>3 steps, 12 components, 2 gems - shipped in 4 weeks. #{"prose " * 15}</p>"

        assert_red_green("numbered-section-markers", red: red, green: green)
      end

      def test_repeated_section_kickers
        kicker = %(<p class="uppercase tracking-widest text-xs">Features</p><h2>One</h2>)
        red = "<section>#{kicker * 3}</section>"
        green = "<section>#{kicker}<h2>Two</h2><h2>Three</h2></section>"

        assert_red_green("repeated-section-kickers", red: red, green: green)
      end

      def test_repeated_section_kickers_skips_nav_chrome
        item = %(<span class="uppercase tracking-wide">Docs</span><h2 class="sr-only">Section</h2>)
        nav = "<nav>#{item * 3}</nav>"

        refute_includes rules_hit(nav), "repeated-section-kickers", "nav chrome never counts"
      end

      def test_hero_eyebrow_chip
        red = %(<p class="uppercase tracking-widest text-xs">New for 2026</p><h1>The headline</h1>)
        green = %(<span data-slot="badge" data-variant="default" class="uppercase tracking-wide">New</span>) +
                %(<h1>The headline</h1>)

        assert_red_green("hero-eyebrow-chip", red: red, green: green)
      end

      def test_oversized_h1
        long = "A very long headline that keeps going well past forty characters total"

        assert_red_green("oversized-h1",
                         red: %(<h1 class="text-8xl font-semibold">#{long}</h1>),
                         green: %(<h1 class="text-8xl font-semibold">Ship faster</h1>))
      end

      def test_rules_registry_documents_every_rule_with_provenance
        assert_equal 20, DesignLint::RULES.size
        DesignLint::RULES.each do |id, (tier, provenance)|
          assert_includes %i[ast dom], tier, id
          assert_match(/the design-rule analogue|the slop-gate analogue|the judged-run calibration|/, provenance,
                       "#{id} must cite its analogue or the measured run that earned it")
        end
      end
    end
  end
end
