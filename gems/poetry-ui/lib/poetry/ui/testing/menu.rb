# frozen_string_literal: true

module Poetry
  module Ui
    module Testing
      # The DropdownMenu interaction contract: trigger toggles, open lands
      # focus in the menu, arrows move data-highlighted, Enter activates
      # the highlighted item, Escape closes with focus returned to the
      # trigger.
      class Menu < Tester
        def open?(wait: 0)
          part?("dropdown-menu-content", wait: wait) &&
            !hidden_part("dropdown-menu-content")["data-open"].nil?
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

          root.assert_selector("[data-slot='dropdown-menu-content'][data-open][data-side]")
          self
        end

        def close
          keys(:escape) if open?
          root.assert_selector("[data-slot='dropdown-menu-content'][data-closed]", visible: :all)
          self
        end

        # Opens first when closed; activates by exact visible text.
        def choose(text, via: :mouse)
          self.open(via: via)

          if via == :keyboard
            walk_highlight_to(text)
            keys(:enter)
          else
            press(item(text))
          end

          self
        end

        def items
          open unless open?
          parts("dropdown-menu-item").map(&:text)
        end

        private

        # Bounded highlight walk: at most one pass over the items - a
        # missing/mistyped label raises instead of arrowing forever.
        def walk_highlight_to(text)
          (parts("dropdown-menu-item").size + 1).times do
            return if highlighted_text == text

            keys(:down)
          end

          raise Capybara::ElementNotFound,
                "no option #{text.inspect} reached by ArrowDown - " \
                "options: #{parts("dropdown-menu-item").map(&:text).inspect}"
        end

        def trigger
          part("dropdown-menu-trigger")
        end

        # Substring match, not exact: menu items legitimately carry more
        # than their label (shortcut glyphs, badges).
        def item(text)
          root.find("[data-slot='dropdown-menu-item']", text: text, match: :first)
        end

        def highlighted_text
          root.find("[data-slot='dropdown-menu-item'][data-highlighted]", wait: 1).text
        rescue Capybara::ElementNotFound
          nil
        end
      end
    end
  end
end
