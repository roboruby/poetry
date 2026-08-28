# frozen_string_literal: true

require_relative "testing/tester"
require_relative "testing/select"
require_relative "testing/combobox"
require_relative "testing/menu"
require_relative "testing/dialog"
require_relative "testing/registration"

module Poetry
  module Ui
    # Consumer-facing interaction testers: drive poetry components
    # through their REAL keyboard/pointer
    # sequences in a Capybara system test and assert against the public
    # attribute contract (data-open, aria-expanded, data-highlighted) -
    # never against markup internals. Each tester is an executable spec of
    # its component's interaction contract; agents are taught to test
    # through them (the usage skill), so generated tests are correct by
    # construction.
    #
    #   require "poetry/ui/testing"
    #
    #   class PlanTest < ApplicationSystemTestCase
    #     include Poetry::Ui::Testing
    #
    #     test "picking a plan" do
    #       visit settings_path
    #       select = poetry_select("#plan")
    #       select.select_option("Pro", via: :keyboard)
    #       assert_equal "pro", select.value
    #     end
    #   end
    #
    # Testers locate parts by data-slot from the root you hand them, and
    # wait with Capybara's own retry discipline - no sleeps. `via:` swaps
    # the ENTIRE event sequence (:mouse clicks, :keyboard focuses the
    # trigger and drives keys), because the two paths exercise different
    # controller seams.
    module Testing
      # Each entry point takes the component ROOT: a CSS selector string
      # or a Capybara node, and an optional session (defaults to
      # Capybara.current_session, or the including test's `page`).

      # A Select tester rooted at the component.
      #
      # @param root [String, Capybara::Node::Element] the component root
      # @param session [Capybara::Session, nil] defaults to the test's
      #   `page` (or Capybara.current_session)
      # @return [Select]
      def poetry_select(root, session: nil)
        Select.new(root, session: session || testing_session)
      end

      # A Combobox tester rooted at the component (single or multiple).
      #
      # @param root [String, Capybara::Node::Element] the component root
      # @param session [Capybara::Session, nil] defaults to the test's
      #   `page` (or Capybara.current_session)
      # @return [Combobox]
      def poetry_combobox(root, session: nil)
        Combobox.new(root, session: session || testing_session)
      end

      # A DropdownMenu tester rooted at the component.
      #
      # @param root [String, Capybara::Node::Element] the component root
      # @param session [Capybara::Session, nil] defaults to the test's
      #   `page` (or Capybara.current_session)
      # @return [Menu]
      def poetry_dropdown_menu(root, session: nil)
        Menu.new(root, session: session || testing_session)
      end

      # A Dialog tester rooted at the component.
      #
      # @param root [String, Capybara::Node::Element] the element carrying
      #   data-component=dialog (trigger + content)
      # @param session [Capybara::Session, nil] defaults to the test's
      #   `page` (or Capybara.current_session)
      # @return [Dialog]
      def poetry_dialog(root, session: nil)
        Dialog.new(root, session: session || testing_session)
      end

      # Every poetry controller identifier on the current page that the
      # host's Stimulus application has NOT registered - empty when the
      # wiring is healthy. Stimulus never errors on an unknown identifier
      # (the element just stays inert), and one failed import in the
      # controllers graph silently takes every poetry controller with it,
      # so nothing else surfaces this.
      #
      # @param session [Capybara::Session, nil] defaults to the test's
      #   `page` (or Capybara.current_session)
      # @param application [String] JS expression naming the Stimulus
      #   application (Rails' default controllers/application.js exposes
      #   window.Stimulus)
      # @return [Array<String>] the unregistered identifiers, sorted
      # @raise [RegistrationError] when no application is reachable at all
      def poetry_unregistered_controllers(session: nil, application: "window.Stimulus")
        result = (session || testing_session).evaluate_script(Registration.script(application))
        raise RegistrationError, result["error"] if result["error"]

        result["missing"]
      end

      # Asserts that every poetry controller on the page is registered.
      # Flunks under Minitest, raises {RegistrationError} elsewhere, with
      # the identifiers and the two causes to check first.
      #
      # @param session [Capybara::Session, nil] defaults to the test's
      #   `page` (or Capybara.current_session)
      # @param application [String] JS expression naming the Stimulus
      #   application (default window.Stimulus)
      # @return [true]
      def assert_poetry_controllers_registered(session: nil, application: "window.Stimulus")
        result = (session || testing_session).evaluate_script(Registration.script(application))
        return true if !result["error"] && result["missing"].empty?

        message = Registration.message(result)
        respond_to?(:flunk, true) ? flunk(message) : raise(RegistrationError, message)
      end

      private

      def testing_session
        respond_to?(:page) ? page : Capybara.current_session
      end
    end
  end
end
