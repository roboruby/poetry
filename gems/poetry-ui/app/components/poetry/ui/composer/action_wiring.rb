# frozen_string_literal: true

module Poetry
  module Ui
    module Composer
      # The action slot's wiring, declared once for the two classes that
      # need it: the composer, whose contract and registry project it, and
      # the slot, which renders it alone when the server redraws it.
      #
      # @api private
      module ActionWiring
        extend ActiveSupport::Concern

        included do
          # A press never takes focus (a field being typed in keeps its
          # on-screen keyboard). Stop pressed from the keyboard does hold
          # it, and its click hands it to the field before the server
          # replaces the button - a replaced element drops focus to the page.
          use_stimulus do
            on :send do
              controller :composer do
                target :send
                action :hold_focus, on: :pointerdown
              end
            end
            on :stop do
              controller :composer do
                target :stop
                action :hold_focus, on: :pointerdown
                action :return_focus, on: :click
              end
            end
          end
        end
      end
    end
  end
end
