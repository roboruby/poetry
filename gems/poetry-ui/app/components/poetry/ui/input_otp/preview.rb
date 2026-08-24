# frozen_string_literal: true

module Poetry
  module Ui
    module InputOtp
      # The InputOTP preview matrix: the four ported examples (demo,
      # pattern, controlled, separator) plus fill states, invalid, and
      # disabled. Values are DUMMIES only - never a real code (the value
      # is a live credential in production).
      class Preview < Poetry::Core::Preview::Base
        # @!group Groupings

        # The input-otp-demo port: 6 digits as [3, 3] with a separator.
        def default
          render_component(name: "code", length: 6, groups: [3, 3],
                           "aria-label": "Verification code")
        end

        # One group of six (no separator rendered for a single group).
        def single_group
          render_component(name: "code", length: 6, "aria-label": "Verification code")
        end

        # The separator example's [2, 2, 2] shape.
        def three_groups
          render_component(name: "code", length: 6, groups: [2, 2, 2],
                           "aria-label": "Verification code")
        end

        # @!endgroup

        # @!group Fill states

        # Server-rendered partial value (no-JS honesty: the chars paint
        # server-side; the caret cell needs the controller).
        def partial
          render_component(name: "code", length: 6, groups: [3, 3], value: "12",
                           "aria-label": "Verification code")
        end

        def complete
          render_component(name: "code", length: 6, groups: [3, 3], value: "123456",
                           "aria-label": "Verification code")
        end

        # @!endgroup

        # @!group States

        # The alphanumeric pattern (input-otp-pattern parity):
        # inputmode=text, autocapitalize off.
        def alphanumeric
          render_component(name: "code", length: 6, pattern: :alphanumeric,
                           "aria-label": "Verification code")
        end

        def disabled
          render_component(name: "code", length: 6, groups: [3, 3], disabled: true,
                           "aria-label": "Verification code")
        end

        # The failed-verify re-render: aria-invalid on the input, the
        # destructive treatment on the cells, value BLANKED (the
        # otp_field default - a rejected code is dead).
        def invalid
          render_component(name: "code", length: 6, groups: [3, 3], invalid: true,
                           "aria-label": "Verification code")
        end

        # @!endgroup

        # @!group Recipes

        # The Field recipe: label 'Verification code', length in the hint,
        # id/describedby landing on the INPUT (the real control).
        def in_a_field
          field = Field::Component.new(
            id: "preview-code", label_text: "Verification code",
            hint: "Enter the 6-digit code we sent to your phone."
          )
          render_component(field) do
            embed(Component.new(name: "code", length: 6, groups: [3, 3],
                                **field.control_attributes.transform_keys(&:to_sym)))
          end
        end

        # @!endgroup
      end
    end
  end
end
