# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The reset floor: preflight's rules at zero specificity, generated
    # from the pinned binary and gated against it.
    class ResetFloorTest < ActiveSupport::TestCase
      test "wraps every top-level selector in :where() and leaves pseudo-elements and at-rules alone" do
        css = <<~CSS
          /*! banner */
          *, ::after, ::before {
            margin: 0;
          }
          h1, h2 {
            font-size: inherit;
          }
          :where(select:is([multiple], [size])) optgroup {
            font-weight: bolder;
          }
          ::placeholder {
            opacity: 1;
          }
          @supports (color: red) {
            ::placeholder {
              color: currentcolor;
            }
          }
          [hidden]:where(:not([hidden='until-found'])) {
            display: none !important;
          }
        CSS
        floor = ResetFloor.floor(css)

        assert floor.start_with?(ResetFloor::HEADER)
        assert_includes floor, ":where(*), ::after, ::before {"
        assert_includes floor, ":where(h1), :where(h2) {"
        assert_includes floor, ":where(:where(select:is([multiple], [size])) optgroup) {"
        assert_includes floor, "\n::placeholder {\n  opacity: 1;"
        assert_includes floor, "@supports (color: red) {\n  ::placeholder {\n    color: currentcolor;"
        assert_includes floor, ":where([hidden]:where(:not([hidden='until-found']))) {\n  display: none !important;"
        refute_includes floor, "banner"
      end

      test "the committed floor matches the pinned preflight" do
        assert_predicate ResetFloor, :verified?, "run `bin/rake reset:generate` and commit"
        text = ResetFloor.path.read

        assert_includes text, ":where(button), :where(input), :where(select), :where(optgroup), :where(textarea)"
        assert_includes text, "border: 0 solid;"
        assert_includes text, "border-collapse: collapse;"
        assert_includes text, "display: none !important;"
      end

      test "entry_state reads a host entry" do
        assert_equal :preflight, ResetFloor.entry_state(%(@import "tailwindcss";\n@import "./poetry/tokens.css";))
        assert_equal :preflight, ResetFloor.entry_state(%(@import 'tailwindcss' source(none);))
        floored = "#{ResetFloor::NO_PREFLIGHT_ENTRY}@import \"./poetry/reset.css\" layer(base);"

        assert_equal :floor, ResetFloor.entry_state(floored)
        assert_equal :none, ResetFloor.entry_state(ResetFloor::NO_PREFLIGHT_ENTRY)
        assert_equal :none, ResetFloor.entry_state(%(@import "tailwindcss/utilities.css" layer(utilities);))
      end
    end
  end
end
