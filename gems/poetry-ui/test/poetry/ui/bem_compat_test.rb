# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The css_mode = :bem compat stylesheet: every template-static class
    # (the classes the dictionaries do not own) compiled to real CSS, with
    # no preflight and no theme rules, colors resolving through the token
    # variables the host defines.
    class BemCompatTest < ActiveSupport::TestCase
      CSS = Poetry::Ui.root.join(Poetry::Ui::BEM_COMPAT_PATH).read

      test "every committed template class compiles into the compat stylesheet" do
        verifier = Poetry::Core::CSS::Verifier.new(compiled_css: CSS)

        assert_empty verifier.unknown(Array(Poetry::Ui.template_classes))
      end

      test "the compat stylesheet is utilities only" do
        refute_match(/::file-selector-button/, CSS, "Tailwind's preflight reset must never reach a bem host")
        refute_match(/\.cn-/, CSS, "the theme layer is the host's in bem mode")
        assert_match(/var\(--muted-foreground\)/, CSS, "colors resolve through the host's token variables")
        assert_match(/\.sr-only \{/, CSS)
        assert_match(/@keyframes spin/, CSS)
      end
    end
  end
end
