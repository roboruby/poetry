# frozen_string_literal: true

module Poetry
  module Ui
    module Command
      # Re-expressed through the cn-* theme layer. The two deliberate
      # source deltas (data-[highlighted] over data-[selected=true]; the
      # ms-auto RTL shortcut) now live in the theme rules. The
      # CommandDialog p-0/overflow-hidden and h-12 retunes stay INLINE
      # deliberately (the source carries them on the component too): they
      # are cross-component overrides whose utilities-layer position is
      # what lets them beat the themed Dialog/Command rules.
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

        # The source's group-heading descendant chain, landed on the part.
        element :heading, "cn-command-group-heading"

        # group/command-item: bare marker, no CSS - the vega shortcut
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

        # CommandDialog: the DialogContent override - the themes' radius
        # retune hook plus the source's structural pair (overflow-hidden
        # p-0), inline so it beats every theme's cn-dialog-content padding
        # (the ports that repeat p-0 in their rule are the source's own
        # duplicates; three ports do not, and relied on this pair).
        element :dialog_content, "cn-command-dialog overflow-hidden p-0"

        # CommandDialog: the source's h-12 inner-part retuning chain,
        # rewritten onto poetry's data-slots per the contract. Stays inline:
        # utilities-layer arbitrary selectors beat the themed part rules -
        # exactly the override behavior the source chain had via cn().
        element :dialog_overrides, "**:data-[slot=command-input-wrapper]:h-12 " \
                                   "[&_[data-slot=command-input]]:h-12 " \
                                   "[&_[data-slot=command-group-heading]]:px-2 " \
                                   "[&_[data-slot=command-group]]:px-2 " \
                                   "[&_[data-slot=command-item]]:px-2 [&_[data-slot=command-item]]:py-3 " \
                                   "[&_[data-slot=command-item]_svg]:h-5 [&_[data-slot=command-item]_svg]:w-5"

        # CommandDialog: the close X seats in the input row as its trailing
        # flex item - never laid over the input, centered by the row in
        # every theme. static beats the themed cn-dialog-close absolute
        # offset (utilities win), shrink-0 keeps the icon button whole
        # beside the w-full input; size and hover stay the theme's ghost
        # icon-sm. Dictionary-held so the safelist harvests it.
        element :dialog_close, "static shrink-0"
      end
    end
  end
end
