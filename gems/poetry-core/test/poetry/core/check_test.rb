# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    # poetry check: the consumer-markup linter. Component/option/
    # variant rules run against an inline catalog (self-contained); the
    # Stimulus wiring rules run against the REAL controllers manifest (a
    # dialog controller genuinely exists in this repo).
    class CheckTest < Minitest::Test
      ICON_ENTRY = {
        "options" => [
          { "name" => "label", "type" => "string" },
          { "name" => "name", "type" => "symbol", "required" => true, "format" => "icon-name" }
        ]
      }.freeze

      CATALOG = Check::Catalog.new(
        {
          "poetry/ui/button" => {
            "options" => [{ "name" => "loading" }, { "name" => "type" }],
            "styles" => [
              { "name" => "variant", "variants" => %w[default destructive outline ghost] },
              { "name" => "size", "variants" => %w[default sm lg] }
            ]
          },
          "poetry/ui/select" => { "options" => [{ "name" => "name" },
                                                { "name" => "placeholder" }] },
          "poetry/ui/icon" => ICON_ENTRY,
          "poetry/ui/alert" => {
            "styles" => [{ "name" => "variant", "variants" => %w[default destructive],
                           "default" => "default", "required" => true }],
            "slots" => [
              { "name" => "icon", "many" => false, "component" => "poetry/ui/icon" },
              { "name" => "title", "many" => false },
              { "name" => "actions", "many" => true },
              { "name" => "rows", "many" => true, "types" => %w[row divider] }
            ],
            "slot_extras" => ["link"]
          }
        },
        helper_entries: {
          "poetry_input_group_addon" => {
            "options" => [{ "name" => "align", "type" => "symbol", "default" => "inline-start",
                            "variants" => %w[inline-start inline-end block-start block-end] }]
          }
        },
        icon_names: %w[circle-alert folder-plus triangle-alert]
      ).freeze

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
        finding = first(%(<%= poetry_zzzzzzzzzzzzzz { "x" } %>), "unknown-component")

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

      # --- value contracts (the crash classes) ---

      def test_a_typed_slot_called_as_a_block_errors_with_the_prop_form
        source = <<~ERB
          <%= poetry_alert(variant: :destructive) do |alert| %>
            <% alert.with_icon do %>
              <%= poetry_icon(name: :"triangle-alert") %>
            <% end %>
          <% end %>
        ERB
        finding = first(source, "missing-option")

        assert_equal :error, finding.severity
        assert_equal 2, finding.line
        assert_includes finding.message, "with_icon(name: ...)"
        assert_includes finding.message, "not a block"
      end

      def test_a_typed_slot_with_props_is_clean
        source = <<~ERB
          <%= poetry_alert do |alert| %>
            <% alert.with_icon(name: :"circle-alert", label: "Careful") %>
            <% alert.with_title { "Heads up" } %>
          <% end %>
        ERB

        assert_empty lint(source), -> { lint(source).join("\n") }
      end

      def test_an_unknown_slot_errors_with_did_you_mean
        source = <<~ERB
          <%= poetry_alert do |alert| %>
            <% alert.with_ttle { "x" } %>
          <% end %>
        ERB
        finding = first(source, "unknown-slot")

        assert_equal :error, finding.severity
        assert_equal "title", finding.suggestion
      end

      def test_a_many_slot_accepts_the_singular_setter
        source = <<~ERB
          <%= poetry_alert do |alert| %>
            <% alert.with_action { "Retry" } %>
          <% end %>
        ERB

        refute_includes rules(source), "unknown-slot"
      end

      def test_unbound_with_calls_are_not_poetrys_to_validate
        refute_includes rules(%(<% form.with_hint { "x" } %>)), "unknown-slot"
      end

      def test_polymorphic_type_setters_and_hand_rolled_conveniences_are_valid
        source = <<~ERB
          <%= poetry_alert do |alert| %>
            <% alert.with_divider %>
            <% alert.with_link("Docs", href: "/docs") %>
          <% end %>
        ERB

        refute_includes rules(source), "unknown-slot"
      end

      def test_a_near_miss_on_a_hand_rolled_convenience_still_suggests
        source = <<~ERB
          <%= poetry_alert do |alert| %>
            <% alert.with_lnk("Docs", href: "/docs") %>
          <% end %>
        ERB
        finding = first(source, "unknown-slot")

        assert_equal "link", finding.suggestion
      end

      def test_an_underscored_icon_name_errors_with_the_kebab_fix
        finding = first(%(<%= poetry_icon(name: :folder_plus) %>), "unknown-icon")

        assert_equal :error, finding.severity
        assert_equal "folder-plus", finding.suggestion
        assert_includes finding.message, "kebab-case"
      end

      def test_an_unknown_kebab_icon_errors_with_a_spellcheck_suggestion
        finding = first(%(<%= poetry_icon(name: :"cirle-alert") %>), "unknown-icon")

        assert_equal "circle-alert", finding.suggestion
      end

      def test_a_nil_icon_name_errors_as_missing
        finding = first(%(<%= poetry_icon(name: nil) %>), "missing-option")

        assert_includes finding.message, "cannot be nil"
      end

      def test_omitting_a_required_option_errors
        finding = first(%(<%= poetry_icon(label: "Plus") %>), "missing-option")

        assert_includes finding.message, "name: is required on poetry_icon"
      end

      def test_a_splatted_call_stands_down_on_required_options
        refute_includes rules(%(<%= poetry_icon(**icon_attrs) %>)), "missing-option"
      end

      def test_a_dynamic_icon_name_is_left_alone
        refute_includes rules(%(<%= poetry_icon(name: item.icon) %>)), "unknown-icon"
      end

      def test_without_a_known_icon_set_the_shape_still_checks
        catalog = Check::Catalog.new({ "poetry/ui/icon" => ICON_ENTRY })

        assert_includes Check.lint(%(<%= poetry_icon(name: :folder_plus) %>), catalog: catalog).map(&:rule),
                        "unknown-icon"
        refute_includes Check.lint(%(<%= poetry_icon(name: :"any-kebab-name") %>), catalog: catalog).map(&:rule),
                        "unknown-icon"
      end

      def test_a_wrapper_helper_enum_violation_errors_with_the_valid_set
        finding = first(%(<%= poetry_input_group_addon(align: :leading) { "@" } %>), "unknown-variant")

        assert_equal :error, finding.severity
        assert_includes finding.message, "poetry_input_group_addon"
        assert_includes finding.message, "inline-start"
      end

      def test_a_wrapper_helper_with_a_valid_enum_is_clean
        assert_empty rules(%(<%= poetry_input_group_addon(align: :"inline-end") { "@" } %>))
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
