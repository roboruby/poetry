# frozen_string_literal: true

module Poetry
  module Ui
    module Textarea
      # Re-expressed through the cn-* theme layer. The one behavioral
      # novelty stays inline: field-sizing-content is CSS-only auto-grow
      # (Chromium-first; other engines fall back to min-h-16 + the native
      # resize handle - graceful, no polyfill, no JS autosizer ever).
      # Placeholder color rides the theme (the rhea AA hold - see
      # the Input dictionary note).
      class Style < Poetry::Core::Style
        base "cn-textarea flex field-sizing-content min-h-16 w-full outline-none " \
             "disabled:cursor-not-allowed disabled:opacity-50"
      end
    end
  end
end
