# frozen_string_literal: true

require "erb"
require "yaml"
require "rails"
require "rails/generators"
require "rails/generators/test_case"
require "minitest/autorun"

require "poetry/jumpstart_pro"
require_relative "support/jumpstart_repo"
require_relative "support/template_tree"
require_relative "../lib/generators/poetry_jumpstart_pro/install/install_generator"

# The shared base for the generator tests: a destination that already has
# Poetry installed, so the install_poetry step never shells out.
class InstallGeneratorTest < Rails::Generators::TestCase
  # A Tailwind entry poetry:install has finished with.
  POETRY_ENTRY = %(@import "tailwindcss";\n@import "./poetry/tokens.css" layer(theme);\n)

  tests PoetryJumpstartPro::InstallGenerator
  setup :prepare_destination
  setup :install_poetry_tokens

  private

  def install_poetry_tokens
    write_host_file(PoetryJumpstartPro::InstallGenerator::POETRY_TOKENS, "/* poetry tokens */\n")
    write_host_file(PoetryJumpstartPro::InstallGenerator::TAILWIND_ENTRY, POETRY_ENTRY)
  end

  def write_host_file(relative, content)
    path = File.join(destination_root, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def read_host_file(relative)
    File.read(File.join(destination_root, relative))
  end
end
