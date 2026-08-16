# frozen_string_literal: true

require_relative "lib/poetry/simple_form/version"

Gem::Specification.new do |spec|
  spec.name = "poetry-simple_form"
  spec.version = Poetry::SimpleForm::VERSION
  spec.authors = ["Matt Solt"]
  spec.summary = "The simple_form migration bridge for poetry: f.input renders poetry Fields."
  spec.description = "An opt-in shim that re-maps simple_form's input types onto poetry's " \
                     "model-bound Field components, so existing simple_form views keep working " \
                     "mid-migration. The end state is Poetry::Ui::FormBuilder - this bridge " \
                     "exists to make getting there boring."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"
  spec.files = Dir["lib/**/*", "README.md"]

  spec.add_dependency "poetry-ui"
  spec.add_dependency "simple_form", ">= 5.3", "< 6"
  spec.metadata["rubygems_mfa_required"] = "true"
end
