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
        assert_match(/bg-primary/, safelist)
        assert_match(/^sr-only$/, safelist, "committed template classes included (no herb needed in a host)")
        assert_match(/^animate-spin$/, safelist)
        assert_operator safelist.lines.size, :>, 100, "the full dictionary, not a stub"
      end
      assert_file "config/initializers/poetry.rb", /icon_library/
      assert_file "config/poetry_components.yml", /components: \{\}/
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
      root.join("app/assets/stylesheets/poetry-charts.css")
          .write("#{CHARTS_CSS_MARKER} { to { stroke-dashoffset: 0; } }\n")

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
      entry = File.read(File.join(destination_root, InstallGenerator::TAILWIND_ENTRY))

      assert_equal 1, entry.scan('@import "./poetry/charts.css";').size, "entry line appended exactly once"
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
