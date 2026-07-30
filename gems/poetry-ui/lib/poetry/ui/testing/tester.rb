# frozen_string_literal: true

module Poetry
  module Ui
    module Testing
      # The tester base: root resolution, part lookup by data-slot (the
      # contract surface - never CSS classes), and Capybara-native waiting.
      # Subclasses encode one component's real interaction sequences.
      class Tester
        attr_reader :session

        def initialize(root, session:)
          @session = session
          @root_locator = root
        end

        # The component root node, re-found on every access so Turbo
        # re-renders never leave the tester holding a stale element.
        def root
          case @root_locator
          when String then session.find(@root_locator)
          else @root_locator
          end
        end

        private

        # A part under the root, by its data-slot name. The error names
        # the missing slot so a wrong root reads as "not a poetry_select",
        # not as an opaque Capybara timeout.
        def part(slot, **)
          root.find(slot_selector(slot), **)
        rescue Capybara::ElementNotFound
          raise Capybara::ElementNotFound,
                "no [data-slot=#{slot}] under #{describe_root} - is this the right component root?"
        end

        def part?(slot, **)
          root.has_selector?(slot_selector(slot), **)
        end

        def parts(slot, **)
          root.all(slot_selector(slot), **)
        end

        # Overlay content PORTALS to body while open (portal-on-open,
        # docs/portal-on-open.md) - root-scoped lookups only hold for
        # closed content and non-overlay parts. Component testers resolve
        # open content document-wide through the trigger's aria-controls
        # id (the production controllers' own rule); visibility flips via
        # hidden/data-open, so look through visibility for closed content.
        def hidden_part(slot)
          root.find(slot_selector(slot), visible: :all)
        end

        def slot_selector(slot)
          "[data-slot='#{slot}']"
        end

        def describe_root
          @root_locator.is_a?(String) ? @root_locator.inspect : "the given node"
        end

        # Real keyboard focus WITHOUT a press (the Tab-arrival reality the
        # keyboard path simulates) - a click would run the pointer seams.
        def focus(node)
          session.execute_script("arguments[0].focus()", node)
          node
        end

        # A real pointer press. Under Cuprite the raw mouse is driven at
        # the element's LIVE center (Cuprite's cached quads can disagree
        # with the settled layout and hit-test the wrong point) - still a
        # genuine CDP pointerdown/up/click sequence, never a synthetic
        # dispatch. Other drivers take Capybara's own click.
        def press(node)
          mouse = session.driver.respond_to?(:browser) && session.driver.browser.respond_to?(:mouse) &&
                  session.driver.browser.mouse

          if mouse
            node.scroll_to(node) if node.respond_to?(:scroll_to)
            x, y = session.evaluate_script(<<~JS, node)
              (() => { const r = arguments[0].getBoundingClientRect();
                       return [r.x + r.width / 2, r.y + r.height / 2]; })()
            JS
            mouse.click(x: x, y: y)
          else
            node.click
          end

          node
        end

        # Keys go to whatever HAS focus (the keyboard reality). Under
        # Cuprite the raw Ferrum keyboard types - pure key events with
        # Ferrum's own simple names (:down, :enter, :escape); a Capybara
        # NODE#send_keys would click-to-focus first, which runs the
        # pointer seams the keyboard path exists to avoid.
        def keys(*sequence)
          keyboard = session.driver.respond_to?(:browser) &&
                     session.driver.browser.respond_to?(:keyboard) &&
                     session.driver.browser.keyboard

          if keyboard
            sequence.each { |key| keyboard.type(key) }
          elsif session.respond_to?(:send_keys)
            session.send_keys(*sequence)
          else
            active_element.send_keys(*sequence)
          end
        end

        def active_element
          session.evaluate_script("document.activeElement") if session.driver.respond_to?(:evaluate_script)
        end

        def wait_until(message)
          Timeout.timeout(Capybara.default_max_wait_time) do
            sleep 0.05 until yield
          end
        rescue Timeout::Error
          raise Capybara::ExpectationNotMet, message
        end
      end
    end
  end
end
