# frozen_string_literal: true

module Poetry
  module Ui
    module Testing
      # The Select interaction contract, executable: open lands focus on
      # the SELECTED option (the Radix-parity delta vs the menu family),
      # committing syncs the native <select> and closes with focus back on
      # the trigger, and the closed trigger typeaheads without opening
      # (native parity). Asserts ride data-open/aria-expanded/the native
      # value - the Base UI contract, not markup internals.
      class Select < Tester
        def open?(wait: 0)
          part?("select-content", wait: wait) &&
            !hidden_part("select-content")["data-open"].nil?
        rescue Capybara::ElementNotFound
          false
        end

        def open(via: :mouse)
          return self if open?

          case via
          when :keyboard
            focus(trigger)
            keys(:down)
          else
            press(trigger)
          end

          root.assert_selector("[data-slot='select-content'][data-open][data-side]")
          self
        end

        def close
          keys(:escape) if open?
          root.assert_selector("[data-slot='select-content'][data-closed]", visible: :all)
          self
        end

        # Opens first when closed; exact visible-text match; waits for the
        # commit to land on the native select before returning.
        def select_option(text, via: :mouse)
          self.open(via: via)

          if via == :keyboard
            walk_highlight_to(text)
            keys(:enter)
          else
            press(option(text))
          end

          root.assert_selector("[data-slot='select-content'][data-closed]", visible: :all)
          self
        end

        # The submitted value - the native <select> is the serialization
        # truth, so this is what the server would receive.
        def value
          hidden_part("select-native").value
        end

        # The trigger's visible value text.
        def text
          part("select-value").text
        end

        def options
          open unless open?
          parts("select-item").map(&:text)
        end

        private

        # Bounded highlight walk: at most one pass over the items - a
        # missing/mistyped label raises instead of arrowing forever.
        def walk_highlight_to(text)
          (parts("select-item").size + 1).times do
            return if highlighted_text == text

            keys(:down)
          end

          raise Capybara::ElementNotFound,
                "no option #{text.inspect} reached by ArrowDown - options: #{parts("select-item").map(&:text).inspect}"
        end

        def trigger
          part("select-trigger")
        end

        def option(text)
          root.find("[data-slot='select-item']", text: text, exact_text: true)
        end

        # Select's active option is REAL FOCUS (the Radix-parity delta vs
        # the menu family, which marks data-highlighted).
        def highlighted_text
          root.find("[data-slot='select-item']:focus", wait: 1).text
        rescue Capybara::ElementNotFound
          nil
        end
      end
    end
  end
end
