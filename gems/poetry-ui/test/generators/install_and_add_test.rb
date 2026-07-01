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
      assert_file "app/assets/tailwind/poetry/safelist.txt", /bg-primary/
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
      assert_equal 1, content.scan('@import "./poetry/tokens.css";').size
      assert_equal 1, content.scan('@source "./poetry/safelist.txt";').size
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
