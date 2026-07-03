# frozen_string_literal: true

module Poetry
  module Ui
    module Command
      # The Command dictionary - shadcn new-york-v4, source-validated
      # 2026-07-03 (Command). Class strings are
      # source-exact per part with TWO deliberate deltas: the highlight
      # attribute data-[selected=true] -> data-[highlighted] (aria-selected
      # is RESERVED for committed values - the Select family twin-write
      # rule; a bare palette has no committed value) with
      # data-[disabled=true] -> data-[disabled] (the family boolean-attr
      # convention), and the shortcut's ml-auto -> ms-auto (the RTL logical
      # fix over source). The source's [&_[cmdk-group-heading]] selector
      # chain on the group becomes the :heading element's own classes -
      # poetry makes the heading a real part. Poetry additions: :loading
      # (cmdk's Command.Loading, not re-exported by ny-v4), :status /
      # :sr_only (the debounced result-count live region), and the named
      # icon size the source inlined on its lucide SearchIcon.
      class Style < Poetry::Core::Style
        base "flex h-full w-full flex-col overflow-hidden rounded-md bg-popover text-popover-foreground"

        element :input_wrapper, "flex h-9 items-center gap-2 border-b px-3"

        # h-10 input inside the h-9 wrapper is source-exact (it clips
        # identically in source; the dialog chain retunes both to h-12) -
        # do not "fix" it to h-9/h-9.
        element :input, "flex h-10 w-full rounded-md bg-transparent py-3 text-sm outline-hidden " \
                        "placeholder:text-muted-foreground disabled:cursor-not-allowed disabled:opacity-50"

        element :list, "max-h-[300px] scroll-py-1 overflow-x-hidden overflow-y-auto"

        element :empty, "py-6 text-center text-sm"

        # POETRY ADDITION: the async-pending affordance (host-toggled).
        element :loading, "py-6 text-center text-sm"

        element :group, "overflow-hidden p-1 text-foreground"

        # The source's [&_[cmdk-group-heading]] chain, landed on the part.
        element :heading, "px-2 py-1.5 text-xs font-medium text-muted-foreground"

        # The ONE class delta vs source: data-[selected=true] ->
        # data-[highlighted] (+ the family's bare data-[disabled]).
        element :item, "relative flex cursor-default items-center gap-2 rounded-sm px-2 py-1.5 text-sm " \
                       "outline-hidden select-none data-[highlighted]:bg-accent " \
                       "data-[highlighted]:text-accent-foreground data-[disabled]:pointer-events-none " \
                       "data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 " \
                       "[&_svg:not([class*='size-'])]:size-4 [&_svg:not([class*='text-'])]:text-muted-foreground"

        # ml-auto -> ms-auto (the contract's RTL logical-property fix).
        element :shortcut, "ms-auto text-xs tracking-widest text-muted-foreground"

        element :separator, "-mx-1 h-px bg-border"

        # POETRY ADDITION: the polite result-count live region.
        element :status, "sr-only"

        # Visually-hidden text fragments (the loading part's sr copy).
        element :sr_only, "sr-only"

        # The source's inline SearchIcon classes, named per part.
        element :search_icon, "size-4 shrink-0 opacity-50"

        # CommandDialog: the DialogContent override (source-exact).
        element :dialog_content, "overflow-hidden p-0"

        # CommandDialog: the source's [&_[cmdk-*]] h-12 retuning chain,
        # rewritten onto poetry's data-slots per the contract (the
        # heading's font/color and the input-wrapper svg sizing from the
        # source chain are redundant with poetry's real parts and dropped
        # by the contract's rewrite).
        element :dialog_overrides, "**:data-[slot=command-input-wrapper]:h-12 " \
                                   "[&_[data-slot=command-input]]:h-12 " \
                                   "[&_[data-slot=command-group-heading]]:px-2 " \
                                   "[&_[data-slot=command-group]]:px-2 " \
                                   "[&_[data-slot=command-item]]:px-2 [&_[data-slot=command-item]]:py-3 " \
                                   "[&_[data-slot=command-item]_svg]:h-5 [&_[data-slot=command-item]_svg]:w-5"
      end
    end
  end
end
