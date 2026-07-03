# frozen_string_literal: true

module Poetry
  module Ui
    module Textarea
      # The Textarea dictionary - shadcn new-york-v4 textarea.tsx,
      # source-validated 2026-07-03 (Textarea). One
      # string, source-exact. The one behavioral novelty is
      # field-sizing-content: CSS-only auto-grow (Chromium-first; other
      # engines fall back to min-h-16 + the native resize handle -
      # graceful, no polyfill, no JS autosizer ever). text-base ->
      # md:text-sm is the source's mobile-zoom guard (16px floor on small
      # viewports).
      class Style < Poetry::Core::Style
        base "flex field-sizing-content min-h-16 w-full rounded-md border border-input " \
             "bg-transparent px-3 py-2 text-base shadow-xs transition-[color,box-shadow] " \
             "outline-none placeholder:text-muted-foreground " \
             "focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
             "disabled:cursor-not-allowed disabled:opacity-50 " \
             "aria-invalid:border-destructive aria-invalid:ring-destructive/20 " \
             "md:text-sm dark:bg-input/30 dark:aria-invalid:ring-destructive/40"
      end
    end
  end
end
