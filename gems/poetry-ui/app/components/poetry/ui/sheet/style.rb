# frozen_string_literal: true

module Poetry
  module Ui
    module Sheet
      # Re-expressed through the cn-* theme layer (N11), still on the
      # native-dialog spine. m-0 and the per-side auto margins moved to the
      # theme TOGETHER (the split-side conflict rule: the side margins must
      # beat m-0, which they only can from the same layer); the UA display
      # guard stays inline.
      class Style < Poetry::Core::Style
        # open:flex, NOT flex: a bare display class would defeat the UA's
        # dialog:not([open]) { display: none } (the Dialog's 2026-07-01
        # browser-pass lesson, inherited here).
        # w-full rides the theme so the sides' w-3/4 beats it in-layer.
        # No `relative`: the top layer discards it and the UA reasserts
        # `absolute`, which pins the sheet to the DOCUMENT edge (it scrolls
        # off-screen when opened below the fold). The UA `:modal` rule keeps
        # it viewport-fixed, so the side auto-margins pin it to the viewport
        # edge as intended.
        element :content, "cn-sheet-content open:flex flex-col"

        # The side branches ride cn-sheet-side-* theme rules (margins,
        # edge borders, sizes, slide animations). Applied to :content by
        # the component via Style.side - the resolver renders variants only
        # at the dictionary root, and the Sheet's root wrapper is
        # non-visual.
        variant :side, {
          top: "cn-sheet-side-top",
          right: "cn-sheet-side-right",
          bottom: "cn-sheet-side-bottom",
          left: "cn-sheet-side-left"
        }

        element :header, "cn-sheet-header flex flex-col"
        element :title, "cn-sheet-title"
        element :description, "cn-sheet-description"
        # mt-auto pins the footer to the bottom edge (source).
        element :footer, "cn-sheet-footer mt-auto flex flex-col"
        element :close, "cn-sheet-close"

        # The side's edge classes for the <dialog> element.
        def self.side(value)
          resolver.variants.fetch(:side).fetch(value.to_sym)
        end
      end
    end
  end
end
