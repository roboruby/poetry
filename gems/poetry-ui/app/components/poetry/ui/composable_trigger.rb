# frozen_string_literal: true

module Poetry
  module Ui
    # Gives an including overlay component a composable trigger:
    # with_trigger(compose: true) yields the trigger's wiring to the
    # block, and the block's output IS the trigger. Without compose: the
    # classic path renders (a composed Button). compose: must be passed
    # explicitly - the slot cannot infer intent from the block itself.
    #
    # The wiring hash is flat and symbol-keyed: the Stimulus behavior the
    # overlay needs on its trigger, plus id/aria/slot where the overlay's
    # trigger anatomy carries them - popper-positioned overlays (popover,
    # hover card, tooltip, dropdown) hand over their full trigger anatomy,
    # the modal family (dialog, alert, sheet, drawer) hands only the open
    # action. data-component stays the caller's either way, so the
    # composed control keeps its own name. Splat the wiring onto a
    # WIRING-FREE control: a receiver with its own data-action would end
    # up with two attributes and the first parsed wins.
    #
    # @example Composing your own control as the trigger
    #   <% menu.with_trigger(compose: true) do |wiring| %>
    #     <%= poetry_sidebar_menu_button(size: :lg, **wiring) do %>...<% end %>
    #   <% end %>
    module ComposableTrigger
      # The compose-mode bullet shared by every includer's AGENT_RULES -
      # projected into the registry, llms.txt, and the agent surface.
      AGENT_RULE =
        "with_trigger(compose: true) { |wiring| ... } composes YOUR control as the trigger: " \
        "the block is yielded the trigger wiring (the Stimulus behavior the overlay needs; " \
        "poppers add id/aria and their trigger slot, modals hand only the open action) - " \
        "splat it onto a wiring-free control (poetry_sidebar_menu_button, a plain tag); " \
        "without compose: the classic composed Button renders."

      private

      # The custom-trigger markup when compose: true, or nil for the
      # default path. Other slot options don't combine with compose -
      # style the composed control itself.
      def composed_trigger(wiring, options = {}, &block)
        return nil unless options.delete(:compose)
        raise ArgumentError, "compose: true requires a block taking |wiring|" unless block

        if options.any?
          raise ArgumentError,
                "with_trigger options #{options.keys.inspect} don't combine with compose: " \
                "true - put styling on the composed control itself"
        end

        attrs = { data: {} }
        wiring.except(:type, "type").each do |key, value|
          name = key.to_s
          if name.start_with?("data-")
            attrs[:data][name.delete_prefix("data-").to_sym] = value
          else
            attrs[name.to_sym] = value
          end
        end
        yield(attrs)
      end
    end
  end
end
