# frozen_string_literal: true

module Poetry
  module Ui
    module Command
      # Re-expressed through the cn-* theme layer (N11). The two deliberate
      # source deltas (data-[highlighted] over data-[selected=true]; the
      # ms-auto RTL shortcut) now live in the theme rules. The
      # CommandDialog p-0/h-12 retunes stay INLINE deliberately: they are
      # cross-component overrides whose utilities-layer position is what
      # lets them beat the themed Dialog/Command rules (dialog_content's
      # panel retune rides the cross-component theme section instead).
      class Style < Poetry::Core::Style
        base "cn-command flex h-full w-full flex-col overflow-hidden"

        element :input_wrapper, "cn-command-input-wrapper flex items-center"

        # h-10 input inside the h-9 wrapper is source-exact (it clips
        # identically in source; the dialog chain retunes both to h-12) -
        # do not "fix" it to h-9/h-9.
        element :input, "cn-command-input flex w-full outline-hidden " \
                        "disabled:cursor-not-allowed disabled:opacity-50"

        element :list, "cn-command-list overflow-x-hidden overflow-y-auto"

        element :empty, "cn-command-empty"

        # POETRY ADDITION: the async-pending affordance (host-toggled).
        element :loading, "py-6 text-center text-sm"

        element :group, "cn-command-group overflow-hidden"

        # The source's [&_[cmdk-group-heading]] chain, landed on the part.
        element :heading, "cn-command-group-heading"

        # group/command-item (N12): bare marker, no CSS - the vega shortcut
        # re-color (group-data-selected/command-item) keys on it.
        element :item, "cn-command-item group/command-item relative flex cursor-default " \
                       "items-center outline-hidden select-none data-[disabled]:pointer-events-none " \
                       "data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0"

        # POETRY ADDITION: the label wrapper is layout-transparent - it
        # mirrors the item's own row (preflight blockifies svg, so a bare
        # span would stack an icon above its text).
        element :item_text, "flex min-w-0 items-center gap-2"

        element :shortcut, "cn-command-shortcut"

        element :separator, "cn-command-separator"

        # POETRY ADDITION: the polite result-count live region.
        element :status, "sr-only"

        # Visually-hidden text fragments (the loading part's sr copy).
        element :sr_only, "sr-only"

        # The source's inline SearchIcon classes, named per part.
        element :search_icon, "cn-command-input-icon"

        # CommandDialog: the DialogContent override (cross-component theme
        # section - p-0 must beat cn-dialog-content's p-6 in-layer).
        element :dialog_content, "cn-command-dialog"

        # CommandDialog: the source's [&_[cmdk-*]] h-12 retuning chain,
        # rewritten onto poetry's data-slots per the contract. Stays inline:
        # utilities-layer arbitrary selectors beat the themed part rules -
        # exactly the override behavior the source chain had via cn().
        element :dialog_overrides, "**:data-[slot=command-input-wrapper]:h-12 " \
                                   "[&_[data-slot=command-input]]:h-12 " \
                                   "[&_[data-slot=command-group-heading]]:px-2 " \
                                   "[&_[data-slot=command-group]]:px-2 " \
                                   "[&_[data-slot=command-item]]:px-2 [&_[data-slot=command-item]]:py-3 " \
                                   "[&_[data-slot=command-item]_svg]:h-5 [&_[data-slot=command-item]_svg]:w-5"

        # CommandDialog: the close recenter. Dialog's themed offset (top-4)
        # suits p-6 content; the palette centers the 32px button in its
        # h-12 input row instead. Stays inline (dictionary-held so the
        # safelist harvests it): utilities beat the themed cn-dialog-close.
        element :dialog_close, "top-2 right-2"
      end
    end
  end
end
