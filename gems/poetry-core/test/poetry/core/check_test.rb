# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    # poetry check: the consumer-markup linter. Component/option/
    # variant rules run against an inline catalog (self-contained); the
    # Stimulus wiring rules run against the REAL controllers manifest (a
    # dialog controller genuinely exists in this repo).
    class CheckTest < Minitest::Test
      CATALOG = Check::Catalog.new({
                                     "poetry/ui/button" => {
                                       "options" => [{ "name" => "loading" }, { "name" => "type" }],
                                       "styles" => [
                                         { "name" => "variant", "variants" => %w[default destructive outline ghost] },
                                         { "name" => "size", "variants" => %w[default sm lg] }
                                       ]
                                     },
                                     "poetry/ui/select" => { "options" => [{ "name" => "name" },
                                                                           { "name" => "placeholder" }] }
                                   }).freeze

      def lint(source) = Check.lint(source, catalog: CATALOG)
      def rules(source) = lint(source).map(&:rule)
      def first(source, rule) = lint(source).find { |finding| finding.rule == rule }

      # --- green: no false positives ---

      def test_a_valid_template_is_clean
        source = <<~ERB
          <%= poetry_button(variant: :destructive, size: :sm, type: "submit", class: "mt-4", data: { turbo: false }) { "Delete" } %>
          <%= poetry_select(name: "country", placeholder: "Pick one") %>
          <button class="bg-primary text-destructive-foreground"
                  data-controller="poetry--core--dialog" data-action="poetry--core--dialog#open">x</button>
        ERB

        assert_empty lint(source), -> { lint(source).join("\n") }
      end

      def test_passthrough_html_attributes_are_not_flagged
        # aria-*, an unknown attr with no close match => intentional passthrough.
        assert_empty rules(%(<%= poetry_button("aria-label": "Save", role: "menuitem") { "S" } %>))
      end

      def test_malformed_ruby_surfaces_as_a_parse_error
        assert_includes rules(%(<%= poetry_button(data-testid: "b") { "x" } %>)), "parse-error"
      end

      # --- unknown component ---

      def test_unknown_component_errors_with_did_you_mean
        finding = first(%(<%= poetry_buton { "x" } %>), "unknown-component")

        assert_equal :error, finding.severity
        assert_equal "poetry_button", finding.suggestion
        assert_equal 1, finding.line
      end

      def test_a_far_off_helper_still_errors_without_a_suggestion
        finding = first(%(<%= poetry_zzzzzz { "x" } %>), "unknown-component")

        assert_equal :error, finding.severity
        assert_nil finding.suggestion
      end

      # --- unknown option (typo) vs passthrough ---

      def test_a_near_miss_option_warns_with_did_you_mean
        finding = first(%(<%= poetry_button(loding: true) { "x" } %>), "unknown-option")

        assert_equal :warning, finding.severity
        assert_equal "loading", finding.suggestion
      end

      def test_an_unrelated_keyword_is_treated_as_passthrough_not_flagged
        refute_includes rules(%(<%= poetry_button(colspan: 2) { "x" } %>)), "unknown-option"
      end

      # --- unknown variant ---

      def test_unknown_variant_errors_with_the_valid_set_and_a_suggestion
        finding = first(%(<%= poetry_button(variant: :destrctive) { "x" } %>), "unknown-variant")

        assert_equal :error, finding.severity
        assert_equal "destructive", finding.suggestion
        assert_includes finding.message, "default, destructive, outline, ghost"
      end

      def test_a_valid_variant_passes
        refute_includes rules(%(<%= poetry_button(variant: :ghost, size: :lg) { "x" } %>)), "unknown-variant"
      end

      def test_a_dynamic_variant_value_is_left_alone
        refute_includes rules(%(<%= poetry_button(variant: some_variant) { "x" } %>)), "unknown-variant"
      end

      # --- Stimulus wiring (real manifest) ---

      def test_unknown_controller_errors
        finding = first(%(<div data-controller="poetry--core--dialogg"></div>), "unknown-controller")

        assert_equal :error, finding.severity
      end

      def test_unknown_action_errors_with_did_you_mean
        finding = first(%(<button data-action="poetry--core--dialog#opn">x</button>), "unknown-action")

        assert_equal "open", finding.suggestion
      end

      def test_unknown_target_errors_with_did_you_mean
        finding = first(%(<div data-poetry--core--dialog-target="dialg"></div>), "unknown-target")

        assert_equal "dialog", finding.suggestion
      end

      def test_host_controllers_are_not_poetrys_to_validate
        assert_empty rules(%(<div data-controller="my-app--widget" data-action="my-app--widget#go"></div>))
      end

      # --- raw color (extension) ---

      def test_raw_color_classes_warn
        finding = first(%(<div class="bg-red-500 p-4 text-primary"></div>), "raw-color")

        assert_equal :warning, finding.severity
        assert_includes finding.message, "bg-red-500"
      end

      def test_semantic_tokens_are_clean
        refute_includes rules(%(<div class="bg-primary text-muted-foreground border-input"></div>)), "raw-color"
      end

      def test_cn_theme_classes_are_sanctioned
        # The N11 theme layer: cn-* names are the sanctioned restyle
        # surface and must never read as off-system classes.
        refute_includes rules(%(<div class="cn-button cn-button-variant-destructive cn-rtl-flip"></div>)),
                        "raw-color"
      end

      # --- output ---

      def test_json_output_is_structured
        parsed = JSON.parse(Check.to_json(lint(%(<%= poetry_buton { "x" } %>))))

        assert_equal "unknown-component", parsed.first.fetch("rule")
        assert_equal "poetry_button", parsed.first.fetch("suggestion")
      end

      def test_text_output_summarizes_counts
        text = Check.to_text(lint(%(<%= poetry_button(variant: :nope) { "x" } %>)))

        assert_includes text, "1 error(s), 0 warning(s)"
      end

      def test_clean_text_output
        assert_equal "poetry check: no issues found", Check.to_text([])
      end
    end
  end
end
