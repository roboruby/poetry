# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/poetry/install/install_generator"
require "generators/poetry/add/add_generator"

module Poetry
  # The availability probe's namespace (the gem is not bundled here).
  module Agent; end

  class InstallGeneratorTest < Rails::Generators::TestCase
    tests Poetry::InstallGenerator
    destination File.expand_path("../tmp/install-dest", __dir__)
    setup :prepare_destination

    def test_installs_tokens_theme_safelist_initializer_and_manifest
      run_generator

      assert_file "app/assets/tailwind/poetry/tokens.css", /--background: oklch\(1 0 0\)/
      assert_file "app/assets/tailwind/poetry/theme.css", /@theme inline/
      assert_file "app/assets/tailwind/poetry/animate.css", /--animate-in/
      assert_file "app/assets/tailwind/poetry/aliases.css", /--radix-dropdown-menu-content-transform-origin/
      assert_file "app/assets/tailwind/poetry/base.css", /background-color: var\(--background\)/
      # NOTE: the cold-boot half (Style.descendants empty until eager_load!)
      # can't be reproduced here - this suite has already loaded every
      # component. The fresh-app install proof covers it.
      assert_file "app/assets/tailwind/poetry/safelist.txt" do |safelist|
        # The visual utilities live in style-default.css (@apply
        # needs no safelisting); the safelist carries cn names + the
        # structural inline set.
        assert_match(/^cn-button$/, safelist)
        assert_match(/^sr-only$/, safelist, "committed template classes included (no herb needed in a host)")
        assert_match(/^animate-spin$/, safelist)
        assert_operator safelist.lines.size, :>, 100, "the full dictionary, not a stub"
      end
      assert_file "app/assets/tailwind/poetry/style-default.css", /\.cn-button \{/
      assert_file "config/initializers/poetry.rb", /icon_library/
      assert_file "config/poetry_components.yml", /components: \{\}/
    end

    def test_install_adds_herb_to_the_development_group_once
      File.write(File.join(destination_root, "Gemfile"), %(source "https://rubygems.org"\ngem "rails"\n))
      run_generator %w[--skip-bundle]
      run_generator %w[--skip-bundle]

      assert_file "Gemfile" do |content|
        assert_equal 1, content.scan(/^gem "herb", group: :development$/).size
        assert_match(/^# poetry:check parses ERB with herb/, content)
      end
    end

    def test_install_leaves_an_existing_herb_entry_alone
      # Any quoting, inside a group block: present is present.
      File.write(File.join(destination_root, "Gemfile"),
                 %(source "https://rubygems.org"\ngroup :development do\n  gem 'herb'\nend\n))
      run_generator %w[--skip-bundle]

      assert_file "Gemfile" do |content|
        assert_equal 1, content.scan(/gem ["']herb["']/).size
        refute_match(/group: :development/, content)
      end
    end

    def test_install_sees_herb_declared_in_an_eval_gemfile_d_file
      # A shared Gemfile pulled in with eval_gemfile (the docs site's
      # layout): herb declared there is declared - the install once added
      # a second copy to the Gemfile proper.
      File.write(File.join(destination_root, "Gemfile.shared"), %(gem "herb", ">= 0.10.3", require: false\n))
      File.write(File.join(destination_root, "Gemfile"),
                 %(source "https://rubygems.org"\neval_gemfile File.expand_path("Gemfile.shared", __dir__)\n))
      run_generator %w[--skip-bundle]

      assert_file "Gemfile" do |content|
        assert_equal 0, content.scan(/gem ["']herb["']/).size, "herb is already declared in Gemfile.shared"
      end
    end

    def test_install_without_a_gemfile_skips_the_herb_step
      run_generator %w[--skip-bundle]

      assert_no_file "Gemfile"
    end

    def test_install_writes_the_agents_md_section_idempotently
      run_generator
      run_generator

      assert_file "AGENTS.md" do |content|
        assert_match(/Building UI with poetry \(\d+ components/, content)
        assert_equal 1, content.scan(Generators::AgentsSection::BEGIN_MARKER).size
      end
    end

    def test_generated_entry_compiles_with_the_real_tailwind_binary
      # The output is EXECUTED, not just inspected: an emitted import path
      # that does not resolve, an order bug between the generated pieces,
      # or a fragment the compiler rejects all pass file-content
      # assertions and detonate on a fresh host's first tailwindcss:build.
      # The re-run first: the idempotent upgrade path must stay compilable.
      run_generator
      run_generator

      compiled = compile_entry

      assert_includes compiled, "--background:", "tokens missing from the compiled host build"
      assert_match(/\.cn-button[\s{,]/, compiled, "safelisted component classes missing from the compiled host build")
      assert_includes compiled, "@media (prefers-reduced-motion: reduce)",
                      "the reduced-motion guard missing from the compiled host build"
    end

    def test_install_writes_both_claude_code_skills
      run_generator

      assert_file ".claude/skills/poetry/SKILL.md" do |content|
        assert_match(/^name: poetry$/, content)
      end
      assert_file ".claude/skills/poetry/references/forms.md"
      assert_file ".claude/skills/poetry-design/SKILL.md" do |content|
        assert_match(/^name: poetry-design$/, content)
      end
      assert_file ".claude/skills/poetry-design/references/audit.md"
      assert_file ".claude/skills/poetry-component/SKILL.md" do |content|
        assert_match(/^name: poetry-component$/, content)
      end
      assert_file ".claude/skills/poetry-component/references/checklist.md"
    end

    def test_tailwind_entry_injection_is_idempotent
      entry = File.join(destination_root, InstallGenerator::TAILWIND_ENTRY)
      FileUtils.mkdir_p(File.dirname(entry))
      File.write(entry, %(@import "tailwindcss";\n))

      run_generator
      run_generator
      content = File.read(entry)

      assert_includes content, %(@import "tailwindcss";), "host content preserved"
      InstallGenerator::ENTRY_LINES.each do |line|
        assert_equal 1, content.scan(line).size, "#{line} appended exactly once"
      end
    end

    def test_poetry_controllers_are_registered_in_the_stimulus_index_once
      index = File.join(destination_root, "app/javascript/controllers/index.js")
      FileUtils.mkdir_p(File.dirname(index))
      File.write(index, <<~JS)
        import { application } from "controllers/application"
        import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
        eagerLoadControllersFrom("controllers", application)
      JS

      run_generator
      run_generator
      content = File.read(index)

      # Pins alone register nothing - the browser pass caught the dialog
      # trigger dead in a fresh host without this call.
      assert_equal 1, content.scan("registerPoetryControllers(application)").size
      assert_includes content, %(import { registerPoetryControllers } from "@poetry/controllers")
    end

    def test_agent_runtime_registers_beside_the_controllers_when_poetry_agent_is_bundled
      index = File.join(destination_root, "app/javascript/controllers/index.js")
      FileUtils.mkdir_p(File.dirname(index))
      File.write(index, %(import { application } from "controllers/application"\n))

      # The gem is not in this test bundle; its engine constant is the
      # availability signal the generator reads.
      Poetry::Agent.const_set(:Engine, Class.new) unless defined?(Poetry::Agent::Engine)
      begin
        run_generator
        run_generator
      ensure
        Poetry::Agent.send(:remove_const, :Engine)
      end
      content = File.read(index)

      assert_equal 1, content.scan("registerPoetryAgent(application)").size
      assert_includes content, %(import { registerPoetryAgent } from "@poetry/agent")
    end

    def test_agent_stylesheet_is_vendored_into_layer_base_when_the_gem_is_bundled
      Dir.mktmpdir do |gem_root|
        FileUtils.mkdir_p(File.join(gem_root, "app/assets/stylesheets"))
        File.write(File.join(gem_root, "app/assets/stylesheets/poetry-agent.css"), ":where(form:tool-form-active) { outline: 2px dashed red; }\n")
        Poetry::Agent.const_set(:Engine, Class.new) unless defined?(Poetry::Agent::Engine)
        Poetry::Agent.define_singleton_method(:root) { Pathname.new(gem_root) }
        run_generator %w[--skip-bundle]
        run_generator %w[--skip-bundle]

        assert_file "app/assets/tailwind/poetry/agent.css", /tool-form-active/
        assert_file "app/assets/tailwind/application.css" do |entry|
          assert_equal 1, entry.scan(InstallGenerator::AGENT_LINE).size, "once, layered"
          lines = entry.lines.map(&:strip)

          assert_operator lines.index(InstallGenerator::AGENT_LINE), :<, lines.index(%(@import "./poetry/base.css";))
        end
      ensure
        Poetry::Agent.singleton_class.remove_method(:root)
        Poetry::Agent.send(:remove_const, :Engine) if defined?(Poetry::Agent::Engine)
      end
    end

    def test_agent_stylesheet_is_not_vendored_without_the_gem
      run_generator %w[--skip-bundle]

      assert_no_file "app/assets/tailwind/poetry/agent.css"
      assert_file "app/assets/tailwind/application.css" do |entry|
        refute_includes entry, "agent.css"
      end
    end

    def test_agent_runtime_is_not_registered_without_the_gem
      index = File.join(destination_root, "app/javascript/controllers/index.js")
      FileUtils.mkdir_p(File.dirname(index))
      File.write(index, %(import { application } from "controllers/application"\n))

      run_generator

      refute_includes File.read(index), "registerPoetryAgent"
    end

    def test_engine_mount_is_added_to_routes_once
      routes = File.join(destination_root, "config/routes.rb")
      FileUtils.mkdir_p(File.dirname(routes))
      File.write(routes, "Rails.application.routes.draw do\nend\n")

      run_generator
      run_generator
      content = File.read(routes)

      assert_equal 1, content.scan("mount Poetry::Ui::Engine").size, "mounted exactly once"
    end

    def test_a_stale_entry_gains_only_the_missing_lines_on_rerun
      entry = File.join(destination_root, InstallGenerator::TAILWIND_ENTRY)
      FileUtils.mkdir_p(File.dirname(entry))
      File.write(entry, %(@import "tailwindcss";\n@import "./poetry/tokens.css";\n@import "./poetry/theme.css";\n))

      run_generator
      content = File.read(entry)

      # The pre-layer tokens line is rewritten in place, not joined by a
      # second import (which would let the old unlayered one win again).
      assert_equal 0, content.scan('@import "./poetry/tokens.css";').size, "superseded line rewritten"
      assert_equal 1, content.scan('@import "./poetry/tokens.css" layer(theme);').size
      assert_equal 1, content.scan('@import "./poetry/theme.css";').size, "pre-existing line not duplicated"
      assert_equal 1, content.scan('@import "./poetry/animate.css";').size, "the upgrade path: new lines appended"
      assert_equal 1, content.lines.index { |line| line.include?("tokens.css") }, "rewritten where it stood"
    end

    def test_tokens_are_defaults_a_host_declaration_beats
      # The two halves of the precedence rule: the tokens import into a
      # cascade layer (a host :root declaration wins from either side of
      # the import) and the theme mapping is @theme default (a host @theme
      # key wins the same way). Without them the appended import took a
      # host's brand colors and its rounded-sm size over.
      run_generator

      assert_file "app/assets/tailwind/application.css", %r{^@import "\./poetry/tokens\.css" layer\(theme\);$}
      assert_file "app/assets/tailwind/poetry/theme.css", /^@theme inline default \{$/
    end

    def test_a_host_that_owns_a_token_name_keeps_it_in_the_compiled_build
      # Executed against the real compiler: the host declares --primary and
      # --radius-sm BEFORE the appended poetry imports, the form that used
      # to lose. The utilities must resolve to the host's values.
      entry = File.join(destination_root, InstallGenerator::TAILWIND_ENTRY)
      FileUtils.mkdir_p(File.dirname(entry))
      File.write(entry, <<~CSS)
        @import "tailwindcss";
        :root { --primary: rgb(255 0 0); }
        @theme { --radius-sm: 1px; --color-brand: rgb(0 0 255); --color-primary: var(--color-brand); }
      CSS
      FileUtils.mkdir_p(File.join(destination_root, "app/views"))
      File.write(File.join(destination_root, "app/views/probe.html"), %(<div class="rounded-sm bg-primary"></div>))
      run_generator

      compiled = compile_entry

      rounded = compiled[/\.rounded-sm\s*\{[^}]*\}/]

      assert rounded, "probe class missing from the build"
      assert_match(/1px|var\(--radius-sm\)/, rounded, "the host's radius must survive: #{rounded}")
      refute_match(/calc\(var\(--radius\)/, rounded, "poetry's default replaced the host's rounded-sm")
      assert_match(/--radius-sm:\s*1px/, compiled) if rounded.include?("var(--radius-sm)")
      bg = compiled[/\.bg-primary\s*\{[^}]*\}/]

      assert bg, "probe class missing from the build"
      assert_match(/var\(--color-primary\)|var\(--color-brand\)|rgb\(0 0 255\)/, bg,
                   "the host's @theme color must survive: #{bg}")
      refute_match(/var\(--primary\)/, bg, "poetry's default replaced the host's --color-primary")
      # The tokens ride the theme layer, so the host's unlayered :root wins the cascade.
      assert_match(/@layer theme\s*\{\s*:root\s*\{[^}]*--background:/m, compiled,
                   "poetry's tokens must sit inside @layer theme")
      assert_includes compiled, "--primary: rgb(255 0 0)", "the host's own :root declaration is kept"
    end

    def test_install_reports_the_host_s_token_collisions_without_blocking
      entry = File.join(destination_root, InstallGenerator::TAILWIND_ENTRY)
      FileUtils.mkdir_p(File.dirname(entry))
      File.write(entry, <<~CSS)
        @import "tailwindcss";
        :root {
          --accent: #ffd400;
          --brand: red;
        }
        @theme { --radius-sm: 1px; }
      CSS

      output = run_generator

      assert_match(/application\.css:3: --accent is yours, so it wins inside poetry's components too/, output)
      assert_match(/--radius-sm is yours/, output)
      refute_match(/--brand/, output, "only poetry's names are reported")
      assert_match(/2 poetry token name\(s\) are already declared/, output)
      assert_file "app/assets/tailwind/poetry/tokens.css", /--background:/
    end

    def test_no_preflight_writes_the_split_entry_and_vendors_the_floor_ahead_of_the_theme
      run_generator %w[--no-preflight --skip-bundle]

      assert_file "app/assets/tailwind/poetry/reset.css", /:where\(button\), :where\(input\)/
      assert_file "app/assets/tailwind/application.css" do |entry|
        assert_includes entry, %(@import "tailwindcss/utilities.css" layer(utilities);)
        refute_match(/^@import "tailwindcss";/, entry, "no preflight on a fresh --no-preflight entry")
        lines = entry.lines.map(&:strip)

        theme_at = lines.index(%(@import "./poetry/style-default.css" layer(base);))

        assert_operator lines.index(InstallGenerator::RESET_LINE), :<, theme_at, "the floor precedes the theme"
        assert_equal :floor, Poetry::Ui::ResetFloor.entry_state(entry)
      end
    end

    def test_a_plain_rerun_keeps_the_floor_once_installed
      run_generator %w[--no-preflight --skip-bundle]
      File.write(File.join(destination_root, InstallGenerator::RESET_FILE), "/* stale */\n")
      run_generator %w[--skip-bundle]

      assert_file "app/assets/tailwind/poetry/reset.css", /:where\(html\)/
      assert_file "app/assets/tailwind/application.css" do |entry|
        assert_equal 1, entry.scan(InstallGenerator::RESET_LINE).size
      end
    end

    def test_a_default_install_vendors_no_floor
      run_generator %w[--skip-bundle]

      assert_no_file "app/assets/tailwind/poetry/reset.css"
      assert_file "app/assets/tailwind/application.css" do |entry|
        assert_match(/^@import "tailwindcss";/, entry)
        refute_includes entry, "reset.css"
      end
    end

    def test_no_preflight_on_an_existing_entry_adds_the_floor_without_touching_the_tailwind_import
      entry = File.join(destination_root, InstallGenerator::TAILWIND_ENTRY)
      FileUtils.mkdir_p(File.dirname(entry))
      File.write(entry, Poetry::Ui::ResetFloor::NO_PREFLIGHT_ENTRY)
      run_generator %w[--no-preflight --skip-bundle]

      assert_file "app/assets/tailwind/application.css" do |content|
        assert content.start_with?(Poetry::Ui::ResetFloor::NO_PREFLIGHT_ENTRY), "the host's own import lines are kept"
        assert_equal 1, content.scan(InstallGenerator::RESET_LINE).size
      end
    end

    def test_install_warns_when_the_entry_has_neither_preflight_nor_the_floor
      entry = File.join(destination_root, InstallGenerator::TAILWIND_ENTRY)
      FileUtils.mkdir_p(File.dirname(entry))
      File.write(entry, Poetry::Ui::ResetFloor::NO_PREFLIGHT_ENTRY)
      output = run_generator %w[--skip-bundle]

      assert_match(/imports Tailwind without preflight and without poetry's reset floor/, output)
      # The warning never installs the floor by itself.
      assert_no_file "app/assets/tailwind/poetry/reset.css"
      refute_match(/without poetry's reset floor/, run_generator(%w[--no-preflight --skip-bundle]))
    end

    def test_a_no_preflight_entry_compiles_with_the_real_tailwind_binary
      run_generator %w[--no-preflight --skip-bundle]
      compiled = compile_entry

      assert_includes compiled, ":where(html)", "the floor is in the build"
      refute_match(/^\s*html, :host \{/, compiled, "preflight is not")
      assert_match(/\.cn-button[\s{,]/, compiled)
    end

    def test_install_stays_quiet_when_the_host_declares_no_poetry_name
      output = run_generator

      refute_match(/is yours, so it wins/, output)
    end

    # -- the --charts flag (cross-repo: poetry-charts) ----------------------
    #
    # poetry-charts is not in this gem's bundle, so the flag is tested
    # against a STUB carrying the two things the generator touches: the
    # Engine constant (the availability probe) and root (the stylesheet
    # source). The real-gem path is the fresh-app install proof's job.

    CHARTS_CSS_MARKER = "@keyframes poetry-chart-line-draw"

    def with_charts_stub
      root = Pathname.new(File.expand_path("../tmp/charts-stub", __dir__))
      FileUtils.mkdir_p(root.join("app/assets/stylesheets"))
      FileUtils.mkdir_p(root.join("themes"))
      root.join("app/assets/stylesheets/poetry-charts.css")
          .write("#{CHARTS_CSS_MARKER} { to { stroke-dashoffset: 0; } }\n")
      root.join("themes/default.css").write(".cn-chart-tick { @apply fill-muted-foreground; }\n")

      charts = Module.new do
        const_set(:Engine, Class.new)
        define_singleton_method(:root) { root }
      end
      Poetry.const_set(:Charts, charts)
      yield
    ensure
      Poetry.send(:remove_const, :Charts) if Poetry.const_defined?(:Charts, false)
    end

    def test_charts_flag_copies_the_motion_stylesheet_and_registers_once
      index = File.join(destination_root, "app/javascript/controllers/index.js")
      FileUtils.mkdir_p(File.dirname(index))
      File.write(index, "import { application } from \"controllers/application\"\n")

      with_charts_stub do
        run_generator %w[--charts]
        run_generator %w[--charts]
      end

      assert_file "app/assets/tailwind/poetry/charts.css", /#{Regexp.escape(CHARTS_CSS_MARKER)}/o
      assert_file "app/assets/tailwind/poetry/style-charts.css", /cn-chart-tick/
      entry = File.read(File.join(destination_root, InstallGenerator::TAILWIND_ENTRY))

      assert_equal 1, entry.scan('@import "./poetry/charts.css";').size, "entry line appended exactly once"
      assert_equal 1, entry.scan('@import "./poetry/style-charts.css" layer(base);').size
      content = File.read(index)

      assert_equal 1, content.scan("registerPoetryChartsControllers(application)").size
      assert_includes content, %(import { registerPoetryChartsControllers } from "@poetry/charts")
    end

    def test_charts_flag_without_the_gem_fails_fast_before_any_file_lands
      # Thor rescues its own error class inside .start (prints, aborts the
      # command chain), so the observable contract is the stderr hint plus
      # the abort - no install work lands.
      stderr = capture(:stderr) { run_generator %w[--charts] }

      assert_match(/gem "poetry-charts"/, stderr)
      assert_no_file "app/assets/tailwind/poetry/tokens.css" # nothing half-installed
      assert_no_file "app/assets/tailwind/poetry/charts.css"
    end

    def test_without_the_flag_charts_wiring_stays_out
      with_charts_stub { run_generator }

      assert_no_file "app/assets/tailwind/poetry/charts.css"
      entry = File.read(File.join(destination_root, InstallGenerator::TAILWIND_ENTRY))

      refute_includes entry, "charts.css", "charts wiring is opt-in even with the gem present"
    end

    # -- the --theme flag (install-time theme selection) --------------------

    def test_unknown_theme_fails_fast_before_any_file_lands
      stderr = capture(:stderr) { run_generator %w[--theme nope] }

      assert_match(/unknown poetry theme "nope"/, stderr)
      assert_match(/default/, stderr, "the error names the shipped themes")
      assert_no_file "app/assets/tailwind/poetry/tokens.css" # nothing half-installed
    end

    def test_theme_default_is_the_implicit_choice
      run_generator

      assert_file "app/assets/tailwind/poetry/style-default.css", /poetry default theme/
    end

    def test_theme_vega_fills_the_same_slot_and_switching_back_is_an_explicit_rerun
      stdout = run_generator %w[--theme vega]

      # The name never says which theme fills the slot, so the install does.
      assert_match(/"vega" fills app\/assets\/tailwind\/poetry\/style-default\.css/, stdout)
      # The SLOT filename never changes - only the content swaps.
      assert_file "app/assets/tailwind/poetry/style-default.css", /poetry vega theme/
      assert_file "app/assets/tailwind/poetry/style-default.css", /rounded-4xl/
      entry = File.read(File.join(destination_root, InstallGenerator::TAILWIND_ENTRY))

      assert_equal 1, entry.scan('@import "./poetry/style-default.css" layer(base);').size

      run_generator %w[--theme default] # switching is EXPLICIT: same slot, overwritten in place

      assert_file "app/assets/tailwind/poetry/style-default.css", /poetry default theme/
      entry = File.read(File.join(destination_root, InstallGenerator::TAILWIND_ENTRY))

      assert_equal 1, entry.scan('@import "./poetry/style-default.css" layer(base);').size,
                   "switching themes never accretes entry lines"
    end

    def test_force_rerun_never_rewrites_host_owned_files_but_refreshes_vendored_ones
      run_generator %w[--skip-bundle]
      manifest = File.join(destination_root, "config/poetry_components.yml")
      File.write(manifest, "components: {}\noverrides:\n  - path: app/assets/tailwind/mine.css\n    reason: declared on purpose\n")
      initializer = File.join(destination_root, "config/initializers/poetry.rb")
      File.write(initializer, "Poetry::Core::Config.current.icon_library = :heroicons\n")
      base = File.join(destination_root, "app/assets/tailwind/poetry/base.css")
      File.write(base, "@layer base { body { color: red; } }\n")
      typeset = File.join(destination_root, "app/assets/tailwind/poetry/typeset.css")
      File.write(typeset, ".typeset { color: red; }\n")
      safelist = File.join(destination_root, "app/assets/tailwind/poetry/safelist.txt")
      File.write(safelist, "stale\n")

      run_generator %w[--skip-bundle --force]

      assert_file "config/poetry_components.yml", /declared on purpose/
      assert_file "config/initializers/poetry.rb", /heroicons/
      assert_file "app/assets/tailwind/poetry/base.css", /color: red/
      assert_file "app/assets/tailwind/poetry/typeset.css", /color: red/
      assert_file "app/assets/tailwind/poetry/safelist.txt" do |text|
        refute_equal "stale\n", text, "a vendored artifact refreshes"
      end
    end

    def test_rerun_without_the_flag_keeps_the_installed_theme
      run_generator %w[--theme vega]

      # The upgrade path: bundle update + plain re-run must refresh
      # the vendored files WITHOUT swapping the app's design.
      stdout = run_generator

      assert_file "app/assets/tailwind/poetry/style-default.css", /poetry vega theme/
      assert_match(/keeping installed theme "vega"/, stdout)
      refute_match(/fills app/, stdout, "a plain re-run reports the kept theme once, not twice")
    end

    def test_unidentifiable_slot_falls_back_to_default_with_a_warning
      run_generator %w[--theme vega]
      File.write(File.join(destination_root, "app/assets/tailwind/poetry/style-default.css"),
                 "/* my hand-rolled theme */\n.cn-button { color: red }\n")

      stdout = run_generator

      assert_match(/could not identify the installed theme/, stdout)
      assert_file "app/assets/tailwind/poetry/style-default.css", /poetry default theme/
    end

    def test_charts_gem_missing_the_requested_theme_fails_fast
      # The stub ships only themes/default.css - poetry-ui has vega, the
      # charts side does not: the install must fail before any file lands.
      stderr = with_charts_stub { capture(:stderr) { run_generator %w[--charts --theme vega] } }

      assert_match(/poetry-charts does not ship theme "vega"/, stderr)
      assert_no_file "app/assets/tailwind/poetry/tokens.css"
      assert_no_file "app/assets/tailwind/poetry/style-charts.css"
    end

    private

    # Runs the real Tailwind binary over the generated entry and returns
    # the build (an entry that fails to compile fails the test).
    def compile_entry
      require "open3"
      require "tailwindcss/ruby"

      Dir.chdir(destination_root) do
        FileUtils.mkdir_p("tmp")
        _out, err, status = Open3.capture3(
          Tailwindcss::Ruby.executable,
          "-i", "app/assets/tailwind/application.css", "-o", "tmp/compiled.css"
        )

        assert_predicate status, :success?, "the generated Tailwind entry failed to compile:\n#{err}"
        File.read("tmp/compiled.css")
      end
    end
  end

  class AddGeneratorTest < Rails::Generators::TestCase
    tests Poetry::AddGenerator
    destination File.expand_path("../tmp/add-dest", __dir__)
    setup :prepare_destination

    def test_add_recipe_installs_files_blocks_and_manifest_entry
      run_generator ["screen-settings"]

      assert_file "app/controllers/settings_controller.rb", /class SettingsController/
      assert_file "app/views/settings/show.html.erb", %r{render "blocks/page_header"}
      assert_file "test/system/settings_show_test.rb", /Usage-based billing/
      # registryDependencies pull the composed blocks through the block path
      assert_file "app/views/blocks/_page_header.html.erb"
      assert_file "app/views/blocks/_section_card.html.erb"
      assert_file "app/views/blocks/_destructive_panel.html.erb"
      assert_file "config/poetry_components.yml" do |manifest|
        assert_includes YAML.safe_load(manifest)["recipes"].keys, "screen-settings"
      end
    end

    def test_add_recipe_skill_bundle_writes_skill_files_and_skips_existing
      FileUtils.mkdir_p(File.join(destination_root, ".claude/skills/poetry"))
      File.write(File.join(destination_root, ".claude/skills/poetry/SKILL.md"), "mine\n")

      run_generator ["skill-poetry"]

      assert_file ".claude/skills/poetry/SKILL.md", "mine\n"
      assert_file ".claude/skills/poetry/references/deciding.md"
    end

    def test_add_button_copies_the_component_and_its_icon_dependency
      run_generator %w[Button]

      assert_file "app/components/poetry/ui/button/component.rb", /class Component < Poetry::Core::Component/
      assert_file "app/components/poetry/ui/button/style.rb"
      assert_file "app/components/poetry/ui/button/component.html.erb"
      assert_file "app/components/poetry/ui/icon/component.rb" # the dependency
      assert_file "config/poetry_components.yml" do |manifest|
        parsed = YAML.safe_load(manifest)

        assert_equal Poetry::Ui::VERSION, parsed["components"]["button"]["version"]
        assert parsed["components"]["icon"]
      end
    end

    def test_local_edits_are_never_clobbered
      run_generator %w[Button]
      local = File.join(destination_root, "app/components/poetry/ui/button/component.rb")
      File.write(local, "# my customized button\n")

      run_generator %w[Button]

      assert_equal "# my customized button\n", File.read(local),
                   "the copy-in model: local edits win, re-add never overwrites"
    end

    def test_unknown_component_raises
      assert_raises(ArgumentError) { run_generator %w[Sparkles] }
    end
  end
end
