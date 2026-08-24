# frozen_string_literal: true

require_relative "testing/tester"
require_relative "testing/select"
require_relative "testing/combobox"
require_relative "testing/menu"
require_relative "testing/dialog"

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

      private

      def testing_session
        respond_to?(:page) ? page : Capybara.current_session
      end
    end
  end
end
