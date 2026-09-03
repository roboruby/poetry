# frozen_string_literal: true

require_relative "lib/poetry/simple_form/version"

Gem::Specification.new do |spec|
  spec.name = "poetry-simple_form"
  spec.version = Poetry::SimpleForm::VERSION
  spec.authors = ["Matt Solt"]
  spec.email = ["mattsolt@gmail.com"]
  spec.summary = "The simple_form migration bridge for Poetry: f.input renders Poetry Fields."
  spec.description = "An opt-in shim that re-maps simple_form's input types onto Poetry's model-bound Field " \
                     "components, so existing simple_form views keep working mid-migration. The end state is " \
                     "Poetry::Ui::FormBuilder - this bridge exists to make getting there boring."
  spec.license = "MIT"
  spec.homepage = "https://poetryui.com"
  spec.required_ruby_version = ">= 3.4.0"
  spec.files = Dir["lib/**/*", "README.md", "LICENSE.txt", "CHANGELOG.md"]

  spec.add_dependency "poetry-ui", "= #{Poetry::SimpleForm::VERSION}"
  spec.add_dependency "simple_form", ">= 5.3", "< 6"
  spec.metadata["homepage_uri"] = "https://poetryui.com"
  spec.metadata["documentation_uri"] = "https://poetryui.com/docs"
  spec.metadata["source_code_uri"] = "https://github.com/roboruby/poetry-simple_form"
  spec.metadata["changelog_uri"] = "https://github.com/roboruby/poetry-simple_form/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/roboruby/poetry-simple_form/issues"
  spec.metadata["rubygems_mfa_required"] = "true"
end
