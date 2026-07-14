# frozen_string_literal: true

module Poetry
  module Ui
    module Testing
      # The Dialog interaction contract: the trigger opens, focus is
      # trapped inside, Escape (or the close affordance) dismisses, and
      # focus RETURNS to the trigger. The root you hand this tester is the
      # element carrying data-component=dialog (trigger + content).
      class Dialog < Tester
        def open?(wait: 0)
          part?("dialog-content", wait: wait) &&
            !hidden_part("dialog-content")["data-open"].nil?
        rescue Capybara::ElementNotFound
          false
        end

        def open(via: :mouse)
          return self if open?

          case via
          when :keyboard
            focus(trigger)
            keys(:enter)
          else
            press(trigger)
          end

          root.assert_selector("[data-slot='dialog-content'][data-open]")
          self
        end

        def close
          keys(:escape) if open?
          root.assert_selector("[data-slot='dialog-content'][data-closed]", visible: :all)
          self
        end

        def title
          part("dialog-title").text
        end

        private

        # The trigger has no slot of its own - it is the consumer's Button
        # wired to the dialog controller's open action (the contract).
        def trigger
          root.find("[data-action*='poetry--core--dialog#open']", match: :first)
        end
      end
    end
  end
end
