# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # METHOD_SUMMARIES is the curated machine projection (the registry's
    # form_builder "methods" map); the docblocks are the human reference
    # for the same methods. This gate keeps the pair honest: every
    # summarized method must exist as public API and carry source
    # documentation (a docblock above its def, or a @!method directive
    # for the define_method'd typed fields), so neither surface rots
    # silently against the other.
    class FormBuilderDocsTest < ActiveSupport::TestCase
      SOURCE = Poetry::Ui::Engine.root.join("app/helpers/poetry/ui/form_builder.rb").read

      def test_every_summarized_method_exists_and_is_documented
        FormBuilder::METHOD_SUMMARIES.keys.flat_map { |key| key.split(" / ") }.each do |name|
          assert FormBuilder.public_method_defined?(name),
                 "METHOD_SUMMARIES names #{name}, which is not a public FormBuilder method"

          documented =
            SOURCE.match?(/#[^\n]*\n\s*def #{Regexp.escape(name)}\b/) ||
            SOURCE.include?("@!method #{name}")

          assert documented, "#{name} is summarized but carries no docblock or @!method directive"
        end
      end
    end
  end
end
