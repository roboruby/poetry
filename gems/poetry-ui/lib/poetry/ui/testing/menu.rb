# frozen_string_literal: true

module Poetry
  module Ui
    module Testing
      # The DropdownMenu interaction contract: trigger toggles, open lands
      # focus in the menu, arrows move data-highlighted, Enter activates
      # the highlighted item, Escape closes with focus returned to the
      # trigger.
      #
      # CONTENT RESOLVES THROUGH THE ID PAIR, document-wide: portal-on-open
      # moves the open menu to body (docs/portal-on-open.md), so root
      # scoping stops holding for the content and its items - the trigger's
      # aria-controls id is the production controllers' own resolution
      # rule, and id-anchored selectors keep Capybara's waiting semantics.
      class Menu < Tester
        def open?(wait: 0)
          session.has_selector?("##{content_id}[data-open]", visible: :all, wait: wait)
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

          session.assert_selector("##{content_id}[data-slot='dropdown-menu-content'][data-open][data-side]")
          self
        end

        def close
          keys(:escape) if open?
          session.assert_selector("##{content_id}[data-closed]", visible: :all)
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
          content.all("[data-slot='dropdown-menu-item']").map(&:text)
        end

        private

        # Bounded highlight walk: at most one pass over the items - a
        # missing/mistyped label raises instead of arrowing forever.
        def walk_highlight_to(text)
          list = content.all("[data-slot='dropdown-menu-item']")

          (list.size + 1).times do
            return if highlighted_text == text

            keys(:down)
          end

          raise Capybara::ElementNotFound,
                "no option #{text.inspect} reached by ArrowDown - " \
                "options: #{list.map(&:text).inspect}"
        end

        def trigger
          part("dropdown-menu-trigger")
        end

        # The trigger's aria-controls names the menu wherever it sits.
        def content_id
          @content_id ||= trigger["aria-controls"]
        end

        def content
          session.find("##{content_id}", visible: :all)
        end

        # Substring match, not exact: menu items legitimately carry more
        # than their label (shortcut glyphs, badges).
        def item(text)
          content.find("[data-slot='dropdown-menu-item']", text: text, match: :first)
        end

        def highlighted_text
          content.find("[data-slot='dropdown-menu-item'][data-highlighted]", wait: 1).text
        rescue Capybara::ElementNotFound
          nil
        end
      end
    end
  end
end
