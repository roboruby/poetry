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
      end
    end
  end
end
