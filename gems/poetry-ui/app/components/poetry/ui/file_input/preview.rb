# frozen_string_literal: true

module Poetry
  module Ui
    module FileInput
      class Preview < Poetry::Core::Preview::Base
        # The compact form control: the Input component with type=file -
        # the browser renders the selection, no JS.
        def default
          render_component(name: "document", "aria-label": "Document")
        end

        def dropzone
          render_component(variant: :dropzone, name: "attachments[]", multiple: true,
                           hint: "PNG, JPG or PDF, up to 10 MB each")
        end

        def dropzone_custom_prompt
          render_component(variant: :dropzone, name: "avatar", accept: "image/*",
                           prompt: "Drop your avatar here", hint: "Square images look best")
        end

        def dropzone_disabled
          render_component(variant: :dropzone, name: "evidence", disabled: true,
                           hint: "Uploads are locked while the case is closed")
        end

        # The limits as options, rejected at intake: accept, size and count;
        # the hint says the same in words.
        def dropzone_limits
          render_component(variant: :dropzone, name: "receipts[]", multiple: true, accept: "image/*,application/pdf",
                           max_size: 5 * 1024 * 1024, min_size: 1024, max_files: 4,
                           hint: "Up to four images or PDFs, 1 KB to 5 MB each")
        end

        # The whole page as the drop target: the overlay shows while files
        # are dragged over the window, and a paste lands here too.
        def dropzone_overlay
          render_component(variant: :dropzone, name: "attachments[]", multiple: true, overlay: true, paste: true,
                           prompt: "Drop files anywhere on the page", hint: "Or paste a screenshot")
        end
      end
    end
  end
end
