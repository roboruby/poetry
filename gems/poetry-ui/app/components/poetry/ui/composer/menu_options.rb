# frozen_string_literal: true

module Poetry
  module Ui
    module Composer
      # A server-fed menu's answer: the options for the word being typed,
      # in the Turbo frame the menu's listbox is. A menu given src: asks
      # that address about the word (?q=word); the view there renders
      # poetry_composer_menu_options with one with_item per match, in the
      # order the server ranks them, and Turbo puts them in the list. The
      # frame's id comes from the request (the Turbo-Frame header), so one
      # view answers whichever composer asked. internal_component!:
      # anatomy, not a registered component.
      #
      # @api private
      class MenuOptions < Poetry::Core::Component
        internal_component!
        include Menus::ItemBuilder
        include OptionMarkup

        # The frame an answer names when no frame asked for it (the address opened by hand).
        FALLBACK_ID = "composer-menu-options"

        option :id, :string, doc: "The listbox to fill. Defaults to the frame that asked (the Turbo-Frame " \
                                  "request header)."
        option :icon, :symbol, doc: "The icon each option leads with, unless it names its own."

        # Runs the block first, so with_item's options are collected before the frame renders.
        # @api private
        def before_render
          content
        end

        # Renders the frame with its options.
        def call
          options = items.each_with_index.map { |item, position| menu_option_tag(item, frame_id, position) }

          content_tag("turbo-frame", safe_join(options), "id" => frame_id)
        end

        # The options with_item collected.
        #
        # @return [Array<Menus::Item>]
        def items
          @items ||= []
        end

        private

        # The frame this answer fills: id:, else the frame that asked.
        def frame_id
          @frame_id ||= id.presence || request&.headers&.[]("Turbo-Frame").presence || FALLBACK_ID
        end
      end
    end
  end
end
