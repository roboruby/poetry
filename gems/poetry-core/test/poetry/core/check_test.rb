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
            "options" => [{ "name" => "loading" }, { "name" => "type" }, { "name" => "label" }],
            "styles" => [
              { "name" => "variant", "variants" => %w[default destructive outline ghost] },
              { "name" => "size", "variants" => %w[default sm lg] }
            ],
            "requires_any" => [
              { "hint" => "nothing visible renders without one", "content" => true,
                "slots" => %w[leading trailing], "options" => %w[loading] }
            ]
          },
          "poetry/ui/command" => {
            "options" => [{ "name" => "placeholder" }], "styles" => [],
            "requires_any" => [
              { "hint" => "the input's accessible name",
                "options" => %w[id aria-label aria-labelledby aria] }
            ]
          },
          "poetry/ui/select" => { "options" => [{ "name" => "name" },
                                                { "name" => "placeholder" }] },
          "poetry/ui/tabs" => {
            "options" => [{ "name" => "label" }],
            "tools" => [{ "name" => "set_value", "description" => "Activate the tab whose value matches.",
                          "executes" => "poetry--core--tabs#setValue" }]
          },
          "poetry/ui/icon" => ICON_ENTRY,
          "poetry/ui/alert" => {
            "styles" => [{ "name" => "variant", "variants" => %w[default destructive],
                           "default" => "default", "required" => true }],
            "slots" => [
              { "name" => "icon", "many" => false, "component" => "poetry/ui/icon" },
              { "name" => "title", "many" => false },
              { "name" => "actions", "many" => true },
              { "name" => "rows", "many" => true, "types" => %w[row divider],
                "setter_args" => { "row" => 1, "divider" => 0 } },
              { "name" => "badge", "many" => false, "component" => "poetry/ui/badge" },
              { "name" => "confirm", "many" => false, "component" => "poetry/ui/button" }
            ],
            "slot_extras" => ["link"]
          },
          "poetry/ui/avatar" => {
            "options" => [{ "name" => "src" }, { "name" => "label" }],
            "requires_content" => "the initials fallback"
          },
          "poetry/ui/badge" => {
            "styles" => [{ "name" => "variant", "variants" => %w[default success] }],
            "requires_content" => "the visible status text",
            "identity" => false
          },
          "poetry/ui/carousel" => {
            "options" => [{ "name" => "label" }],
            "slots" => [
              { "name" => "items", "many" => true,
                "setter_kwargs" => { "item" => ["classes"] },
                "yieldless" => ["item"],
                "required_content" => { "item" => "the slide" } }
            ]
          },
          "poetry/ui/menubar" => {
            "styles" => [], "options" => [],
            "required_slots" => { "menu" => "at least one menu" },
            "slots" => [
              { "name" => "menus", "many" => true, "setter_args" => { "menu" => 0 },
                "builders" => {
                  "menu" => {
                    "required_slots" => { "trigger" => "the top-level menu button",
                                          "item" => "at least one item" },
                    "slots" => [
                      { "name" => "trigger", "many" => false, "setter_args" => { "trigger" => 0 } },
                      { "name" => "items", "many" => true, "types" => %w[item separator checkbox_item],
                        "setter_args" => { "item" => 0, "separator" => 0, "checkbox_item" => 0 } }
                    ]
                  }
                } }
            ]
          }
        },
        helper_entries: {
          "poetry_input_group_addon" => {
            "options" => [{ "name" => "align", "type" => "symbol", "default" => "inline-start",
                            "variants" => %w[inline-start inline-end block-start block-end] }]
          },
          "poetry_sidebar_group" => {},
          "poetry_webmcp_form" => { "yields" => "the form builder" },
          "poetry_chart" => { "yields" => "the dispatched chart component" }
        },
        icon_names: %w[circle-alert folder-plus triangle-alert],
        helper_args: { "poetry_button" => 0, "poetry_sidebar_group" => 0, "poetry_chart" => 1,
                       "poetry_webmcp_form" => 0 }
      ).freeze

      def lint(source) = Check.lint(source, catalog: CATALOG)
      def rules(source) = lint(source).map(&:rule)
      def first(source, rule) = lint(source).find { |finding| finding.rule == rule }

      # A merged multi-gem catalog (the docs host shape): poetry/charts/*
      # components must map to their poetry_* helpers exactly like
      # poetry/ui/* ones (before this, pathless chart helpers read as
      # yielding wrappers and every `do |chart|` block was a
      # yieldless-block error).
      MERGED_CATALOG = Check::Catalog.new(
        {
          "poetry/ui/badge" => { "options" => [{ "name" => "variant" }] },
          "poetry/charts/area_chart" => {
            "options" => [{ "name" => "data", "required" => true }, { "name" => "config", "required" => true }],
            "slots" => [{ "name" => "areas", "many" => true }, { "name" => "grid", "many" => false }]
          }
        }
      ).freeze

      # --- WebMCP rules ---

      def test_webmcp_on_a_component_with_tools_is_clean
        assert_empty rules(%(<%= poetry_tabs(label: "Sections", webmcp: "sections") do |tabs| %><% end %>))
      end

      def test_webmcp_on_a_component_without_tools_is_an_error
        finding = first(%(<%= poetry_select(name: "plan", webmcp: "plan") %>), "webmcp-without-tools")

        assert_equal :error, finding.severity
        assert_match(/poetry_select declares no agent tools/, finding.message)
      end

      def test_webmcp_names_follow_the_grammar_and_never_repeat
        assert_includes rules(%(<%= poetry_tabs(webmcp: "Bad Name") do |t| %><% end %>)), "webmcp-name"

        source = <<~ERB
          <%= poetry_tabs(webmcp: "sections") do |t| %><% end %>
          <%= poetry_tabs(webmcp: "sections") do |t| %><% end %>
        ERB
        duplicate = first(source, "webmcp-duplicate-name")

        assert_equal :warning, duplicate.severity
        assert_equal 2, duplicate.line
        assert_match(/already names the instance on line 1/, duplicate.message)
      end

      def test_webmcp_composed_names_get_a_length_warning_past_chromes_guidance
        assert_empty rules(%(<%= poetry_tabs(webmcp: "sections") do |t| %><% end %>))
        finding = first(%(<%= poetry_tabs(webmcp: "the_settings_of_the_account_page") do |t| %><% end %>),
                        "webmcp-name-budget")

        assert_equal :warning, finding.severity
        assert_match(/poetry\.the_settings_of_the_account_page\.set_value \(\d+ chars\)/, finding.message)
      end

      def test_webmcp_form_autosubmit_is_get_only
        tool = %(tool: { name: "a", description: "b", autosubmit: true })
        mutating = "<%= poetry_webmcp_form(url: \"/x\", #{tool}) do |f| %><% end %>"

        assert_includes rules(mutating), "webmcp-autosubmit"
        assert_empty rules(mutating.sub("url:", "method: :get, url:"))
        plain = %(<%= poetry_webmcp_form(url: "/x", tool: { name: "a", description: "b" }) do |f| %><% end %>)

        assert_empty rules(plain)
      end

      def test_toolautosubmit_markup_is_get_only
        assert_includes rules(%(<form toolname="x" tooldescription="y" toolautosubmit method="post"></form>)),
                        "webmcp-autosubmit"
        assert_empty rules(%(<form toolname="x" tooldescription="y" toolautosubmit method="get"></form>))
        assert_empty rules(%(<form toolname="x" tooldescription="y" toolautosubmit></form>))
      end

      def test_the_catalog_exposes_the_element_level_stimulus_wiring
        catalog = Poetry::Core::Check::Catalog.from_registry(Poetry::Core.root)

        assert_equal [], catalog.stimulus_wiring("poetry/core/nope")
        assert_kind_of Array, catalog.stimulus_wiring("poetry/core/box")
      end

      def test_a_charts_component_helper_maps_to_its_path_in_a_merged_catalog
        findings = Check.lint(<<~ERB, catalog: MERGED_CATALOG)
          <%= poetry_area_chart(data: data, config: config) do |chart| %>
            <% chart.with_grid %>
          <% end %>
        ERB

        assert_empty findings.select { |f| f.rule == "yieldless-block" },
                     "a slot-yielding chart block is not a yieldless wrapper block"
      end

      def test_a_charts_helper_still_checks_its_option_contract
        findings = Check.lint(%(<%= poetry_area_chart(data: d, config: c, variant: :x) %>), catalog: MERGED_CATALOG)

        assert(findings.none? { |f| f.rule == "unknown-component" }, "poetry_area_chart resolves")
      end

      # --- ERB comments are prose, not Ruby ---

      def test_an_erb_comment_mentioning_helpers_is_never_parsed_as_ruby
        source = <<~ERB
          <%# The search pattern: the control inside must be
              poetry_input_group_addon (a plain poetry_button double-chromes it). %>
          <%= poetry_button(variant: "default") { "Go" } %>
        ERB

        assert_empty lint(source).reject { |f| f.rule == "requires-any" },
                     "comment prose must produce no helper findings"
      end

      # --- helper arity (the blocks-gate site_nav crash class) ---

      def test_positional_text_on_a_kwargs_only_helper_is_a_helper_arity_error
        finding = first(%(<%= poetry_button "Delete", variant: :destructive %>), "helper-arity")

        assert_equal :error, finding.severity
        assert_match(/options are keywords, content is the block/, finding.message)
      end

      def test_a_declared_positional_arity_allows_up_to_the_limit
        assert_empty rules(%(<%= poetry_chart :bar, data: rows %>)),
                     "poetry_chart declares args 1 - one positional is its real signature"
        finding = first(%(<%= poetry_chart :bar, :extra %>), "helper-arity")

        assert_match(/at most 1 positional argument/, finding.message)
      end

      def test_receivered_calls_own_their_signatures
        assert_empty rules(%(<%= form.poetry_button "Save" %>)),
                     "a form builder's poetry_* methods are not view-helper calls"
      end

      def test_helpers_without_a_declared_arity_stay_unchecked
        assert_empty rules(%(<%= poetry_select "country" %>)),
                     "no helper_args key means unknowable - legacy registries stay lint-identical"
      end

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

      # --- value contracts (the argument-shape crash classes) ---

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

      def test_a_reversed_compound_icon_gets_the_rename_suggestion
        # Lucide v1 swapped modifier and noun (alert-circle -> circle-alert);
        # edit distance never bridges the reversal.
        finding = first(%(<%= poetry_icon(name: :"alert-circle") %>), "unknown-icon")

        assert_equal "circle-alert", finding.suggestion
      end

      # --- the declaration tier (icon names living in app Ruby) ---

      def declaration_findings(ruby)
        Check::IconDeclarations.new(CATALOG).lint(ruby)
      end

      def test_an_unknown_name_in_an_icon_keyed_pair_warns_with_a_suggestion
        finding = declaration_findings(%(FLASH = { success: { icon: "cirle-alert" } })).first

        assert_equal "icon-declaration", finding.rule
        assert_equal :warning, finding.severity
        assert_equal "circle-alert", finding.suggestion
        assert_includes finding.message, "icon"
      end

      def test_a_reversed_compound_declaration_gets_the_rename_suggestion
        finding = declaration_findings(%(icon_for(icon: :"alert-circle"))).first

        assert_equal "circle-alert", finding.suggestion
      end

      def test_a_frozen_icon_constant_hash_harvests_its_values
        findings = declaration_findings(<<~RUBY)
          STATUS_ICONS = { ok: :"circle-alert", bad: :"triangl-alert" }.freeze
        RUBY

        assert_equal 1, findings.length
        assert_includes findings.first.message, "triangl-alert"
        assert_equal "triangle-alert", findings.first.suggestion
      end

      def test_an_icon_name_array_constant_harvests_each_element
        findings = declaration_findings(%(ICON_NAMES = %w[circle-alert cirle-alert]))

        assert_equal 1, findings.length
        assert_equal "circle-alert", findings.first.suggestion
      end

      def test_a_snake_case_declaration_of_a_real_icon_warns_with_the_kebab_fix
        finding = declaration_findings(%(tile = { icon: :circle_alert })).first

        assert_equal "circle-alert", finding.suggestion
        assert_includes finding.message, "kebab-case"
      end

      def test_valid_declarations_and_non_name_values_stay_silent
        assert_empty declaration_findings(<<~RUBY)
          FLASH_ICONS = { success: :"circle-alert", notice: :"triangle-alert" }.freeze
          legacy = { icon: "fa fa-home" }
          layout(icon_position: :left)
        RUBY
      end

      def test_declarations_stand_down_without_a_known_icon_set
        catalog = Check::Catalog.new({ "poetry/ui/icon" => ICON_ENTRY })

        assert_empty Check::IconDeclarations.new(catalog).lint(%(ICON = :"not-a-real-icon"))
      end

      def test_unparseable_ruby_is_not_a_declaration_finding
        assert_empty declaration_findings("def broken(; end")
      end

      def test_the_runner_routes_ruby_to_the_declaration_tier_and_erb_to_the_linter
        Dir.mktmpdir("check-declarations") do |dir|
          ruby = File.join(dir, "flash_helper.rb")
          erb = File.join(dir, "show.html.erb")
          File.write(ruby, %(ICONS = { bad: :"cirle-alert" }))
          File.write(erb, %(<%= poetry_icon(name: :"cirle-alert") %>))

          findings = Check::Runner.new(CATALOG).run([ruby, erb])

          assert_equal %w[icon-declaration unknown-icon], findings.map(&:rule)
          assert_equal [ruby, erb], findings.map(&:file)
        end
      end

      # --- composition contracts (the block-seam crash classes) ---

      def test_a_declared_yielding_dispatcher_block_param_is_not_yieldless
        refute_includes rules(%(<%= poetry_chart :line, data: rows do |chart| %>x<% end %>)),
                        "yieldless-block",
                        "a helpers-section yields declaration exempts the dispatcher"
      end

      def test_a_wrapper_block_param_errors_as_yieldless
        finding = first(%(<%= poetry_sidebar_group do |group| %>x<% end %>), "yieldless-block")

        assert_equal :error, finding.severity
        assert_includes finding.message, "poetry_sidebar_group yields nothing"
      end

      def test_a_wrapper_plain_block_is_fine
        refute_includes rules(%(<%= poetry_sidebar_group do %>x<% end %>)), "yieldless-block"
        refute_includes rules(%(<%= poetry_input_group_addon { "@" } %>)), "yieldless-block"
      end

      def test_a_component_block_param_is_not_yieldless
        refute_includes rules(%(<%= poetry_alert do |alert| %>x<% end %>)), "yieldless-block"
      end

      # --- the tier gaps: setter block seams, setter keywords, required content ---

      def test_a_block_param_on_a_yieldless_setter_errors
        source = <<~ERB
          <%= poetry_carousel(label: "Art") do |carousel| %>
            <% carousel.with_item do |item| %>
              <% item.with_leading { "x" } %>
            <% end %>
          <% end %>
        ERB
        finding = first(source, "yieldless-block")

        assert_equal :error, finding.severity
        assert_includes finding.message, "with_item yields nothing to its block"
        assert_includes finding.message, "the param will be nil"
      end

      def test_a_plain_block_on_a_yieldless_setter_is_fine
        source = %(<%= poetry_carousel(label: "Art") do |carousel| %><% carousel.with_item { "x" } %><% end %>)

        refute_includes rules(source), "yieldless-block"
      end

      def test_a_builder_setter_block_param_is_not_yieldless
        source = %(<%= poetry_menubar do |menubar| %><% menubar.with_menu do |menu| %>x<% end %><% end %>)

        refute_includes rules(source), "yieldless-block"
      end

      def test_an_unknown_keyword_on_a_closed_setter_errors_with_did_you_mean
        source = %(<%= poetry_carousel(label: "Art") do |carousel| %>
          <% carousel.with_item(class: "basis-full") { "x" } %>
        <% end %>)
        finding = first(source, "slot-keyword")

        assert_equal :error, finding.severity
        assert_includes finding.message, "with_item does not take class:"
        assert_includes finding.message, "takes classes:"
        assert_equal "classes", finding.suggestion
      end

      def test_a_declared_keyword_on_a_closed_setter_passes
        source = %(<%= poetry_carousel(label: "Art") do |carousel| %>
          <% carousel.with_item(classes: "basis-full") { "x" } %>
        <% end %>)

        refute_includes rules(source), "slot-keyword"
      end

      def test_setters_without_a_keyword_contract_stay_unchecked
        source = %(<%= poetry_alert do |alert| %><% alert.with_actions(anything: "goes") { "x" } %><% end %>)

        refute_includes rules(source), "slot-keyword"
      end

      def test_a_blockless_call_on_a_requires_content_component_errors
        finding = first(%(<%= poetry_avatar(src: "x.png", label: "Nadia") %>), "missing-content-block")

        assert_equal :error, finding.severity
        assert_equal "poetry_avatar requires a content block (the initials fallback)", finding.message
      end

      def test_a_block_satisfies_requires_content
        refute_includes rules(%(<%= poetry_avatar(label: "Nadia") do %>NA<% end %>)), "missing-content-block"
      end

      def test_chained_with_content_satisfies_requires_content
        refute_includes rules(%(<%= poetry_avatar(label: "Nadia").with_content("NA") %>)),
                        "missing-content-block"
      end

      def test_positional_arguments_stand_down_requires_content
        refute_includes rules(%(<%= poetry_avatar("NA") %>)), "missing-content-block"
      end

      def test_a_setter_that_requires_content_errors_without_a_block
        source = %(<%= poetry_carousel(label: "Art") do |carousel| %><% carousel.with_item(classes: "b") %><% end %>)
        finding = first(source, "missing-content-block")

        assert_equal "with_item requires a content block (the slide)", finding.message
      end

      def test_a_typed_slot_rendering_a_requires_content_component_errors_without_a_block
        source = %(<%= poetry_alert do |alert| %><% alert.with_badge(variant: :success) %><% end %>)
        finding = first(source, "missing-content-block")

        assert_includes finding.message, "with_badge renders poetry_badge"
        assert_includes finding.message, "the visible status text"
        refute_includes rules(%(<%= poetry_alert do |alert| %><% alert.with_badge { "Active" } %><% end %>)),
                        "missing-content-block"
      end

      # --- the any-of contract tier (the empty-render crash classes) ---

      def test_a_button_satisfying_no_alternative_errors
        finding = first(%(<%= poetry_button(variant: :destructive, label: "Delete account") %>),
                        "requires-any")

        assert_equal :error, finding.severity
        assert_equal "poetry_button requires one of a content block / with_leading / " \
                     "with_trailing / loading: (nothing visible renders without one)", finding.message
      end

      def test_any_alternative_satisfies_the_button_contract
        assert_empty rules(%(<%= poetry_button(variant: :outline) { "Save" } %>))
        refute_includes rules(%(<%= poetry_button(loading: true) %>)), "requires-any"
        refute_includes rules(%(<%= poetry_button(loading: false) %>)), "requires-any",
                        "presence counts statically - a literal-false loading is the runtime's to catch"
        refute_includes rules(%(<%= poetry_button do |button| %>x<% end %>)), "requires-any",
                        "a block param may feed with_leading inside - the block stands the rule down"
      end

      def test_an_options_only_group_is_not_satisfied_by_a_block
        source = %(<%= poetry_command do |command| %><% end %>)
        finding = first(source, "requires-any")

        assert_includes finding.message, "poetry_command requires one of id: / aria-label: / " \
                                         "aria-labelledby: / aria: (the input's accessible name)"
        refute_includes rules(%(<%= poetry_command("aria-label": "Commands") do |c| %><% end %>)),
                        "requires-any"
        refute_includes rules(%(<%= poetry_command(id: "palette") do |c| %><% end %>)), "requires-any"
        refute_includes rules(%(<%= poetry_command(aria: { label: "Commands" }) do |c| %><% end %>)),
                        "requires-any"
      end

      def test_requires_any_stand_downs
        refute_includes rules(%(<%= form.poetry_button %>)), "requires-any"
        refute_includes rules(%(<%= poetry_button(**options) %>)), "requires-any"
        refute_includes rules(%(<%= poetry_button "Save" %>)), "requires-any",
                        "positionals are an unknowable content path (helper-arity owns that call)"
      end

      def test_a_typed_slot_rendering_an_any_of_component_errors_without_content
        source = %(<%= poetry_alert do |alert| %><% alert.with_confirm(label: "Retry") %><% end %>)
        finding = first(source, "requires-any")

        assert_includes finding.message, "with_confirm renders poetry_button"
        assert_includes finding.message, "one of a content block / loading:"
        refute_includes finding.message, "with_leading",
                        "sub-slot alternatives are unreachable through a slot call"
        refute_includes rules(%(<%= poetry_alert do |alert| %><% alert.with_confirm { "Retry" } %><% end %>)),
                        "requires-any"
        refute_includes rules(%(<%= poetry_alert do |alert| %><% alert.with_confirm(loading: true) %><% end %>)),
                        "requires-any"
      end

      # --- the required-slot tier (the menu crash class - required slots the contract kept silent) ---

      def test_a_bound_block_that_never_sets_a_required_slot_errors
        source = <<~ERB
          <%= poetry_menubar do |menubar| %>
            <% menubar.with_menu do |menu| %>
              <% menu.with_item { "New Tab" } %>
            <% end %>
          <% end %>
        ERB
        finding = first(source, "missing-slot")

        assert_equal :error, finding.severity
        assert_equal "with_menu requires with_trigger (the top-level menu button)", finding.message
      end

      def test_a_component_block_that_never_opens_the_required_collection_errors
        source = %(<%= poetry_menubar do |menubar| %>static<% end %>)
        finding = first(source, "missing-slot")

        assert_equal "poetry_menubar requires with_menu (at least one menu)", finding.message
      end

      def test_any_type_of_a_polymorphic_slot_satisfies_the_requirement
        source = <<~ERB
          <%= poetry_menubar do |menubar| %>
            <% menubar.with_menu do |menu| %>
              <% menu.with_trigger { "File" } %>
              <% menu.with_checkbox_item { "Show sidebar" } %>
            <% end %>
          <% end %>
        ERB

        refute_includes rules(source), "missing-slot"
      end

      def test_a_satisfied_requirement_across_erb_chunks_is_clean
        source = <<~ERB
          <%= poetry_menubar do |menubar| %>
            <% menubar.with_menu do |menu| %>
              <div class="px-2">
                <% menu.with_trigger { "File" } %>
              </div>
              <% menu.with_item { "New" } %>
            <% end %>
          <% end %>
        ERB

        refute_includes rules(source), "missing-slot"
      end

      def test_a_blockless_call_on_a_required_slot_component_errors
        finding = first(%(<%= poetry_menubar %>), "missing-slot")

        assert_includes finding.message, "poetry_menubar requires with_menu (at least one menu)"
        assert_includes finding.message, "open a block"
      end

      def test_blockless_stand_downs_for_required_slots
        assert_empty rules(%(<%= poetry_menubar(menu: prebuilt) %>)),
                     "a same-named keyword may carry the requirement invisibly"
        assert_empty rules(%(<%= poetry_menubar("File") %>)),
                     "positional arguments are an unknowable content path"
        assert_empty rules(%(<%= poetry_menubar(**options) %>)),
                     "a splat may set anything statically invisible"
        assert_empty rules(%(<%= form.poetry_menubar %>)),
                     "a receiver'd call owns its own contract"
      end

      def test_an_escaped_block_param_stands_down_the_accounting
        source = <<~ERB
          <%= poetry_menubar do |menubar| %>
            <%= render "shared/menus", bar: menubar %>
          <% end %>
        ERB

        refute_includes rules(source), "missing-slot"
      end

      def test_rebinding_a_param_name_accounts_each_instance_separately
        source = <<~ERB
          <%= poetry_menubar do |bar| %>
            <% bar.with_menu do |menu| %>
              <% menu.with_item { "Orphan" } %>
            <% end %>
          <% end %>
          <%= poetry_menubar do |bar| %>
            <% bar.with_menu do |menu| %>
              <% menu.with_trigger { "File" } %>
              <% menu.with_item { "New" } %>
            <% end %>
          <% end %>
        ERB
        findings = lint(source).select { |finding| finding.rule == "missing-slot" }

        assert_equal 1, findings.size, -> { findings.join("\n") }
        assert_equal 2, findings.first.line
      end

      def test_a_type_symbol_passed_positionally_suggests_the_sibling_setter
        source = <<~ERB
          <%= poetry_menubar do |menubar| %>
            <% menubar.with_menu do |menu| %>
              <% menu.with_item(:separator) %>
            <% end %>
          <% end %>
        ERB
        finding = first(source, "slot-arity")

        assert_equal :error, finding.severity
        assert_equal "with_separator", finding.suggestion
        assert_includes finding.message, "keyword options only"
      end

      def test_the_type_as_argument_convention_is_named_in_the_message
        source = <<~ERB
          <%= poetry_menubar do |menubar| %>
            <% menubar.with_menu do |menu| %>
              <% menu.with_item(:item, shortcut: "⌘T") { "New Tab" } %>
            <% end %>
          <% end %>
        ERB
        finding = first(source, "slot-arity")

        assert_nil finding.suggestion
        assert_includes finding.message, "the type is the setter"
        assert_includes finding.message, "with_separator"
      end

      def test_nested_builder_slots_validate_through_the_binding
        source = <<~ERB
          <%= poetry_menubar do |menubar| %>
            <% menubar.with_menu do |menu| %>
              <% menu.with_itm { "x" } %>
            <% end %>
          <% end %>
        ERB
        finding = first(source, "unknown-slot")

        assert_includes finding.message, "with_menu has no slot itm"
        assert_equal "item", finding.suggestion
      end

      def test_kwargs_only_setters_stay_clean_within_the_builder
        source = <<~ERB
          <%= poetry_menubar do |menubar| %>
            <% menubar.with_menu do |menu| %>
              <% menu.with_trigger { "File" } %>
              <% menu.with_item(shortcut: "⌘T") { "New Tab" } %>
              <% menu.with_separator %>
            <% end %>
          <% end %>
        ERB

        assert_empty lint(source), -> { lint(source).join("\n") }
      end

      def test_a_positional_within_declared_arity_passes_and_excess_errors
        clean = <<~ERB
          <%= poetry_alert do |alert| %>
            <% alert.with_row("only") %>
          <% end %>
        ERB
        over = <<~ERB
          <%= poetry_alert do |alert| %>
            <% alert.with_row("one", "two") %>
          <% end %>
        ERB

        refute_includes rules(clean), "slot-arity"
        assert_includes first(over, "slot-arity").message, "at most 1 positional argument"
      end

      def test_a_splatted_setter_call_stands_down_on_arity
        source = <<~ERB
          <%= poetry_alert do |alert| %>
            <% alert.with_divider(*args) %>
          <% end %>
        ERB

        refute_includes rules(source), "slot-arity"
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

      # --- Stimulus wiring through helper kwargs (the same rules) ---

      def test_a_data_action_kwarg_on_a_helper_checks_like_the_attribute
        finding = first(%(<%= poetry_button(data: { action: "click->poetry--core--dialog#opn" }) do %>x<% end %>),
                        "unknown-action")

        assert_equal "open", finding.suggestion
        assert_equal 1, finding.line
      end

      def test_a_data_controller_kwarg_on_a_helper_checks_like_the_attribute
        finding = first(%(<%= poetry_button(data: { controller: "poetry--core--dialogg" }) do %>x<% end %>),
                        "unknown-controller")

        assert_equal :error, finding.severity
      end

      def test_a_namespaced_target_kwarg_checks_in_both_spellings
        finding = first(%(<%= poetry_button(data: { "poetry--core--dialog-target": "dialg" }) do %>x<% end %>),
                        "unknown-target")

        assert_equal "dialog", finding.suggestion
        # Rails dasherizes every underscore, so the symbol form renders the same attribute
        symbol_form = %(<%= poetry_button(data: { poetry__core__dialog_target: "dialg" }) do %>x<% end %>)

        assert_equal "dialog", first(symbol_form, "unknown-target").suggestion
      end

      def test_data_kwargs_on_a_slot_setter_check_too
        finding = first(<<~ERB, "unknown-action")
          <%= poetry_alert(variant: :default) do |alert| %>
            <% alert.with_confirm(data: { action: "click->poetry--core--dialog#clos" }) { "ok" } %>
          <% end %>
        ERB

        assert_equal "close", finding.suggestion
        assert_equal 2, finding.line
      end

      def test_data_kwargs_naming_host_controllers_or_dynamic_values_are_left_alone
        host = %(<%= poetry_button(data: { action: "click->cart#add", controller: "cart" }) do %>x<% end %>)
        dynamic = %(<%= poetry_button(data: { action: "click->poetry--core--dialog#\#{verb}" }) do %>x<% end %>)

        assert_empty rules(host)
        assert_empty rules(dynamic)
      end

      # --- Stimulus values (typed, from the manifest) ---

      def test_unknown_value_errors_with_did_you_mean
        typo = %(<div data-controller="poetry--core--dialog" data-poetry--core--dialog-hotkeyy-value="k"></div>)
        finding = first(typo, "unknown-value")

        assert_equal "hotkey", finding.suggestion
      end

      def test_value_names_are_stimulus_dasherized_js_names
        assert_empty rules(%(<div data-poetry--core--calendar-week-start-value="1"></div>))
        assert_equal "week-start",
                     first(%(<div data-poetry--core--calendar-weekstart-value="1"></div>), "unknown-value").suggestion
      end

      def test_value_literals_must_parse_as_their_declared_type
        boolean = first(%(<div data-poetry--core--dialog-dismissible-value="yes"></div>), "value-type")

        assert_includes boolean.message, "Boolean"
        assert_includes first(%(<div data-poetry--core--calendar-week-start-value="soon"></div>), "value-type").message,
                        "not a number"
        array = first(%(<div data-poetry--core--calendar-month-names-value="Jan,Feb"></div>), "value-type")

        assert_includes array.message, "JSON array"
        assert_includes first(%(<div data-poetry--core--date-field-labels-value="x"></div>), "value-type").message,
                        "JSON object"
        valid = <<~ERB
          <div data-poetry--core--dialog-dismissible-value="false" data-poetry--core--dialog-hotkey-value="k"
               data-poetry--core--calendar-month-names-value='["J","F"]'></div>
        ERB

        assert_empty rules(valid)
      end

      def test_value_rules_run_on_data_kwargs_and_leave_dynamic_values_alone
        kwarg = %(<%= poetry_button(data: { poetry__core__dialog_dismissible_value: "maybe" }) do %>x<% end %>)
        finding = first(kwarg, "value-type")

        assert_equal 1, finding.line
        dynamic = %(<div data-poetry--core--calendar-week-start-value="<%= start %>"></div>)

        assert_empty rules(dynamic)
      end

      def test_host_controllers_are_not_poetrys_to_validate
        assert_empty rules(%(<div data-controller="my-app--widget" data-action="my-app--widget#go"></div>))
      end

      # --- raw color ---

      def test_raw_color_classes_warn
        finding = first(%(<div class="bg-red-500 p-4 text-primary"></div>), "raw-color")

        assert_equal :warning, finding.severity
        assert_includes finding.message, "bg-red-500"
      end

      def test_semantic_tokens_are_clean
        refute_includes rules(%(<div class="bg-primary text-muted-foreground border-input"></div>)), "raw-color"
      end

      def test_cn_theme_classes_are_sanctioned
        # The theme layer: cn-* names are the sanctioned restyle
        # surface and must never read as off-system classes.
        refute_includes rules(%(<div class="cn-button cn-button-variant-destructive cn-rtl-flip"></div>)),
                        "raw-color"
      end

      def test_arbitrary_color_values_warn
        findings = lint(%(<div class="hover:bg-[#6366f1] text-[oklch(0.7_0.1_250)] ring-[rgb(99,102,241)]"></div>))
                   .select { |finding| finding.rule == "raw-color" }

        assert_equal 3, findings.size
        assert_includes findings.first.message, "hover:bg-[#6366f1]"
      end

      def test_token_references_and_shadows_are_not_raw_colors
        clean = %(<div class="bg-[var(--brand)] text-(--fg) fill-[url(#grad)] shadow-[0_1px_0_rgba(0,0,0,.1)]"></div>)

        refute_includes rules(clean), "raw-color"
      end

      def test_class_keyword_on_a_component_call_is_scanned
        findings = lint(%(<%= poetry_button(class: "bg-red-500 hover:bg-[#dc2626]") { "Delete" } %>))
                   .select { |finding| finding.rule == "raw-color" }

        assert_equal(%w[bg-red-500 hover:bg-[#dc2626]], findings.map { |finding| finding.message[/"([^"]+)"/, 1] })
        assert_equal [1, 1], findings.map(&:line)
      end

      def test_class_keyword_on_wrapper_helpers_and_slot_calls_is_scanned
        wrapper = %(<%= poetry_sidebar_group(class: "bg-[#fff]") do %>x<% end %>)
        slot = <<~ERB
          <%= poetry_alert(variant: :default) do |alert| %>
            <% alert.with_icon(name: "circle-alert", class: "text-[#f00]") %>
            <% alert.with_title(class: "text-rose-500") { "Heads up" } %>
          <% end %>
        ERB

        assert_includes rules(wrapper), "raw-color"
        assert_equal 2, rules(slot).count("raw-color")
      end

      def test_important_modifier_warns_in_both_spellings
        findings = lint(%(<div class="pl-0.5! !mt-0 hover:flex! p-4"></div>))
                   .select { |finding| finding.rule == "important-modifier" }

        assert_equal(%w[pl-0.5! !mt-0 hover:flex!], findings.map { |finding| finding.message[/"([^"]+)"/, 1] })
        assert_equal :warning, findings.first.severity
      end

      def test_important_modifier_reads_class_keywords_too
        assert_includes rules(%(<%= poetry_button(class: "px-2!") { "Go" } %>)), "important-modifier"
      end

      def test_a_bang_inside_an_arbitrary_value_is_not_the_modifier
        refute_includes rules(%(<div class="before:content-['!'] not-first:mt-2 [&:not(:last-child)]:mb-1"></div>)),
                        "important-modifier"
      end

      def test_inline_style_colors_warn
        attribute = lint(%(<div style="color: #333; background: rgb(1, 2, 3)"></div>))
                    .select { |finding| finding.rule == "raw-color" }
        keyword = lint(%(<%= poetry_button(style: "background: oklch(0.5 0.2 30)") { "Go" } %>))

        assert_equal(["#333", "rgb(1, 2, 3)"], attribute.map { |finding| finding.message[/"([^"]+)"/, 1] })
        assert_includes attribute.first.message, "inline style"
        assert_includes keyword.map(&:rule), "raw-color"
      end

      def test_inline_style_tokens_and_fragments_are_clean
        clean = %(<div style="--chart-1: var(--primary); background: var(--muted); mask: url(#abc)"></div>)

        assert_empty rules(clean)
      end

      def test_dynamic_class_and_style_are_left_alone
        assert_empty rules(%(<div class="<%= classes %>" style="<%= styles %>"></div>))
        assert_empty rules(%(<%= poetry_button(class: "bg-red-500 \#{extra}") { "Go" } %>))
      end

      # --- fake buttons ---

      def test_a_div_with_onclick_or_role_button_is_a_fake_button
        onclick = first(%(<div class="cursor-pointer" onclick="save()">Save</div>), "fake-button")
        role = first(%(<span role="button" tabindex="0">Print</span>), "fake-button")

        assert_equal :warning, onclick.severity
        assert_includes onclick.message, "<div> with onclick"
        assert_includes role.message, %(<span> with role="button")
        assert_includes role.message, "poetry_button"
      end

      def test_real_controls_and_inert_roles_are_not_fake_buttons
        clean = <<~ERB
          <button type="button" onclick="save()">Save</button><a role="button" href="#">Go</a>
          <div role="presentation" class="p-4">x</div><div data-action="click->modal#open">x</div>
        ERB

        refute_includes rules(clean), "fake-button"
      end

      def test_a_dynamic_role_is_left_alone_but_a_dynamic_onclick_still_counts
        refute_includes rules(%(<div role="<%= role %>">x</div>)), "fake-button"
        assert_includes rules(%(<div onclick="<%= handler %>">x</div>)), "fake-button"
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

      # --- StableId heuristics: warnings only, never exit-flipping ---

      def stable_identity_findings(erb)
        Check::StableIdentity.new(CATALOG).lint(erb)
      end

      def test_cache_block_component_without_identity_warns
        findings = stable_identity_findings(<<~ERB)
          <% cache ["sidebar", current_user] do %>
            <%= poetry_button(label: "Save") %>
          <% end %>
        ERB

        assert_equal ["stable-identity/cache"], findings.map(&:rule)
        assert_equal [:warning], findings.map(&:severity)
      end

      def test_cache_block_component_with_key_or_id_is_clean
        findings = stable_identity_findings(<<~ERB)
          <% cache @project do %>
            <%= poetry_button(key: "save-action", label: "Save") %>
            <%= poetry_select(id: "project-picker", name: "p") %>
          <% end %>
        ERB

        assert_empty findings
      end

      def test_collection_loop_component_without_identity_warns
        findings = stable_identity_findings(<<~ERB)
          <% @messages.each do |message| %>
            <%= poetry_button(label: message.subject) %>
          <% end %>
        ERB

        assert_equal ["stable-identity/collection"], findings.map(&:rule)
      end

      def test_keyed_collection_and_outside_blocks_are_clean
        findings = stable_identity_findings(<<~ERB)
          <%= poetry_button(label: "Standalone") %>
          <% @messages.each do |message| %>
            <%= poetry_button(key: message, label: message.subject) %>
          <% end %>
          <% if admin? %>
            <%= poetry_button(label: "Admin") %>
          <% end %>
        ERB

        assert_empty findings, "standalone, keyed-in-loop, and plain-conditional calls are all fine"
      end

      def test_nested_blocks_resolve_extents
        findings = stable_identity_findings(<<~ERB)
          <% cache @page do %>
            <% if @page.hero? %>
              <%= poetry_button(label: "Hero") %>
            <% end %>
          <% end %>
          <%= poetry_button(label: "After") %>
        ERB

        assert_equal 1, findings.size, "the if-block end must not close the cache frame"
        assert_equal "stable-identity/cache", findings.first.rule
      end

      def test_identity_free_component_is_skipped_while_a_minting_neighbor_warns
        findings = stable_identity_findings(<<~ERB)
          <% cache @project do %>
            <%= poetry_badge %>
            <%= poetry_button(label: "Save") %>
          <% end %>
          <% @rows.each do |row| %>
            <%= poetry_badge %>
          <% end %>
        ERB

        assert_equal ["stable-identity/cache"], findings.map(&:rule)
        assert_includes findings.first.message, "poetry_button",
                        "only the minting neighbor warns - badge's entry declares identity false"
      end

      def test_identity_free_reads_the_registry_declaration
        assert CATALOG.identity_free?("poetry_badge")
        refute CATALOG.identity_free?("poetry_button"), "no identity key = minting (legacy registries keep warning)"
        refute CATALOG.identity_free?("poetry_sidebar_group"), "pathless helpers read as minting"
        refute CATALOG.identity_free?("poetry_nonexistent")
      end

      def test_key_is_passthrough_not_an_unknown_option
        # The linter must never flag the identity API its own
        # stable-identity rules recommend.
        findings = Check::Linter.new(CATALOG).lint(<<~ERB)
          <%= poetry_button(key: "save-action", label: "Save") %>
        ERB

        assert_empty(findings.select { |f| f.rule == "unknown-option" })
      end
    end
  end
end
