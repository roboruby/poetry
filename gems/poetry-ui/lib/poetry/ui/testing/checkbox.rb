# frozen_string_literal: true

module Poetry
  module Ui
    module Testing
      # The Checkbox (and Switch) interaction contract: the visible control
      # is a button (role=checkbox, or role=switch) mirroring a native
      # input that carries the form value; a press toggles it from the
      # pointer, Space from the keyboard, and aria-checked is the state
      # ("true", "false", or "mixed" for an indeterminate parent). The
      # root you hand this tester is the control itself, or any element
      # holding one (a Field, a row).
      #
      # @example Accepting the terms from the keyboard
      #   terms = poetry_checkbox("#user_terms")
      #   terms.check(via: :keyboard)
      #   assert terms.checked?
      #   assert_equal "1", terms.value
      class Checkbox < Tester
        # The control's aria-checked state.
        #
        # @return [String] "true", "false" or "mixed"
        def state
          control["aria-checked"].to_s
        end

        # Whether the control is checked.
        #
        # @return [Boolean]
        def checked? = state == "true"

        # Whether the control is indeterminate (a select-all parent over a
        # partial selection).
        #
        # @return [Boolean]
        def mixed? = state == "mixed"

        # Toggles the control once. via: :keyboard focuses it and presses
        # Space; :mouse presses it.
        #
        # @param via [Symbol] :mouse presses the control, :keyboard focuses it and presses Space
        # @return [Checkbox] self
        def toggle(via: :mouse)
          before = state
          case via
          when :keyboard
            focus(control)
            keys(:space)
          else
            press(control)
          end

          wait_until("the control did not toggle from aria-checked=#{before.inspect}") { state != before }
          self
        end

        # Checks the control (no-op when already checked).
        #
        # @param via [Symbol] :mouse or :keyboard
        # @return [Checkbox] self
        def check(via: :mouse)
          toggle(via: via) unless checked?
          self
        end

        # Unchecks the control (no-op when already unchecked).
        #
        # @param via [Symbol] :mouse or :keyboard
        # @return [Checkbox] self
        def uncheck(via: :mouse)
          toggle(via: via) if checked?
          self
        end

        # What the form submits for this control right now: the native
        # input's value when checked, the paired hidden input's value
        # when unchecked, nil for a visual-only control.
        #
        # @return [String, nil]
        def value
          input = native_input
          return nil unless input
          return input["value"] if checked?

          hidden = root.all("input[type='hidden'][name='#{input["name"]}']", visible: :all).first
          hidden && hidden["value"]
        end

        private

        # The visible control: the root when it is one, else the first
        # checkbox or switch under it.
        def control
          node = root
          return node if %w[checkbox switch].include?(node["role"])

          node.find("[role='checkbox'], [role='switch']", match: :first)
        rescue Capybara::ElementNotFound
          raise Capybara::ElementNotFound,
                "no [role=checkbox] or [role=switch] under #{describe_root} - is this the right component root?"
        end

        # The native input carrying the form value, or nil for a
        # visual-only control (the input is a sibling of the button, so it
        # is looked up beside the control).
        def native_input
          node = control
          node.first(:xpath, "following-sibling::input[@type='checkbox'] | .//input[@type='checkbox']",
                     visible: :all, minimum: 0)
        end
      end
    end
  end
end
