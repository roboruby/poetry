# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/poetry/install/install_generator"
require "generators/poetry/add/add_generator"

module Poetry
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
        # Post-N11 the visual utilities live in style-default.css (@apply
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

      require "open3"
      require "tailwindcss/ruby"

      compiled = Dir.chdir(destination_root) do
        FileUtils.mkdir_p("tmp")
        _out, err, status = Open3.capture3(
          Tailwindcss::Ruby.executable,
          "-i", "app/assets/tailwind/application.css", "-o", "tmp/compiled.css"
        )

        assert_predicate status, :success?, "the generated Tailwind entry failed to compile:\n#{err}"
        File.read("tmp/compiled.css")
      end

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
      File.write(entry, %(@import "tailwindcss";\n@import "./poetry/tokens.css";\n))

      run_generator
      content = File.read(entry)

      assert_equal 1, content.scan('@import "./poetry/tokens.css";').size, "pre-existing line not duplicated"
      assert_equal 1, content.scan('@import "./poetry/animate.css";').size, "the upgrade path: new lines appended"
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

    # -- the --theme flag (N12: install-time theme selection) ---------------

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
      run_generator %w[--theme vega]

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

    def test_rerun_without_the_flag_keeps_the_installed_theme
      run_generator %w[--theme vega]

      # The upgrade path: bundle update + plain re-run must refresh
      # the vendored files WITHOUT swapping the app's design.
      stdout = run_generator

      assert_file "app/assets/tailwind/poetry/style-default.css", /poetry vega theme/
      assert_match(/keeping installed theme "vega"/, stdout)
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
  end

  class AddGeneratorTest < Rails::Generators::TestCase
    tests Poetry::AddGenerator
    destination File.expand_path("../tmp/add-dest", __dir__)
    setup :prepare_destination

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
