# frozen_string_literal: true

module Poetry
  module Ui
    module SensitiveInput
      class Preview < Poetry::Core::Preview::Base
        # Masked: the group IS the reveal affordance (click/Enter/Space);
        # the value re-masks on blur, Escape, or the eye.
        def default
          render_component(name: "api_key", label: "API key",
                           value: "sk_demo_4eC39HqLyjWDarjtT1zdp7dc")
        end

        # copy: adds copy-WITHOUT-revealing (the clipboard-text engine).
        def with_copy
          render_component(name: "api_key", label: "API key",
                           value: "sk_demo_4eC39HqLyjWDarjtT1zdp7dc", copy: true)
        end

        # readonly: reveal and copy still work; editing never does.
        def readonly
          render_component(name: "api_key", label: "API key", readonly: true,
                           value: "sk_demo_4eC39HqLyjWDarjtT1zdp7dc", copy: true)
        end

        # Empty: a plain password field; the first character typed
        # auto-reveals so composition happens visibly.
        def empty
          render_component(name: "new_secret", label: "New secret",
                           placeholder: "Paste the token…")
        end

        def disabled
          render_component(name: "api_key", label: "API key",
                           value: "rotated-out", disabled: true)
        end
      end
    end
  end
end
