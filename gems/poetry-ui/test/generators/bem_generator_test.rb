# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/poetry/bem/bem_generator"

module Poetry
  class BemGeneratorTest < Rails::Generators::TestCase
    tests Poetry::BemGenerator
    destination File.expand_path("../tmp/bem-dest", __dir__)
    setup :prepare_destination

    def test_vendors_the_compat_stylesheet_and_writes_the_reference
      run_generator

      assert_file "app/assets/stylesheets/poetry/bem-compat.css", /\.sr-only \{/, /@keyframes spin/
      assert_file "app/assets/stylesheets/poetry/bem-reference.css" do |css|
        assert_match(/poetry BEM reference for `\.poetry-ui-button`/, css)
        assert_match(/\.poetry-ui-button--variant-outline \{/, css)
      end
    end

    def test_the_compat_is_vendored_on_rerun_and_the_reference_stays_yours
      run_generator
      File.write(File.join(destination_root, "app/assets/stylesheets/poetry/bem-compat.css"), "stale")
      File.write(File.join(destination_root, "app/assets/stylesheets/poetry/bem-reference.css"), "/* mine */\n")
      run_generator

      assert_file "app/assets/stylesheets/poetry/bem-compat.css", /\.sr-only \{/
      assert_file "app/assets/stylesheets/poetry/bem-reference.css", %r{\A/\* mine \*/\n\z}
    end
  end
end
