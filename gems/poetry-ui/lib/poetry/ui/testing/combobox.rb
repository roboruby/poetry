# frozen_string_literal: true

module Poetry
  module Ui
    module Testing
      # The Combobox interaction contract, both modes: open, FILTER by
      # typing into the command input, commit an option; single-select
      # closes on commit and the native select serializes, multiple keeps
      # the popover open, grows chips, and serializes name[] through a
      # native select-multiple.
      #
      # CONTENT RESOLVES THROUGH THE ID PAIR, document-wide: portal-on-open
      # moves the open popup to body (docs/portal-on-open.md), so root
      # scoping stops holding for the content and its items. The trigger
      # (single) or the chips inline input (multiple) carries aria-controls
      # naming the listbox; the content wrapper is its ancestor -
      # id-anchored selectors keep Capybara's waiting semantics.
      class Combobox < Tester
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

          session.assert_selector("##{content_id}[data-slot='combobox-content'][data-open][data-side]")
          self
        end

        def close
          keys(:escape) if open?
          session.assert_selector("##{content_id}[data-closed]", visible: :all)
          self
        end

        # Type into the filter input (opens first when closed). Single mode
        # keeps the input inside the (portaled) popup; multiple keeps it
        # inline in the chips field at home.
        def filter(query)
          open
          filter_input.set(query)
          self
        end

        # Commit by exact visible text; single-select waits for the close,
        # multiple leaves the popover up (assert on values/chips instead).
        def select_option(text, via: :mouse)
          self.open(via: via)

          if via == :keyboard
            walk_highlight_to(text)
            keys(:enter)
          else
            press(option(text))
          end

          self
        end

        # Single: the committed value. Multiple: the committed value list.
        def value
          native = hidden_part("combobox-native")
          native.multiple? ? native.value : native.value.to_s
        end

        def chips
          parts("combobox-chip").map(&:text)
        end

        # Remove a chip by its accessible text (multiple mode).
        def remove_chip(text)
          press(root.find("[data-slot='combobox-chip']", text: text).find("button"))
          self
        end

        private

        # Bounded highlight walk: at most one pass over the items - a
        # missing/mistyped label raises instead of arrowing forever.
        def walk_highlight_to(text)
          items = content.all("[data-slot='command-item']", visible: :all)

          (items.size + 1).times do
            return if highlighted_text == text

            keys(:down)
          end

          raise Capybara::ElementNotFound,
                "no option #{text.inspect} reached by ArrowDown - options: #{items.map(&:text).inspect}"
        end

        def trigger
          part("combobox-trigger")
        end

        # The aria-controls anchor stays HOME in both modes: the trigger
        # button (single) or the chips frame's inline input (multiple).
        def list_id
          @list_id ||= root.first(
            "[data-slot='combobox-trigger'], [data-slot='combobox-chips'] [data-slot='command-input']",
            minimum: 1, visible: :all
          )["aria-controls"]
        end

        def content_id
          @content_id ||= session.find("##{list_id}", visible: :all)
                                 .ancestor("[data-slot='combobox-content']", visible: :all)[:id]
        end

        def content
          session.find("##{content_id}", visible: :all)
        end

        def filter_input
          content.first("[data-slot='command-input']", minimum: 0, visible: :all) || part("command-input")
        end

        def option(text)
          content.find("[data-slot='command-item']", text: text, exact_text: true)
        end

        def highlighted_text
          content.find("[data-slot='command-item'][data-highlighted]", wait: 1).text
        rescue Capybara::ElementNotFound
          nil
        end
      end
    end
  end
end
