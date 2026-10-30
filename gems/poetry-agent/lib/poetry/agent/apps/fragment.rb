# frozen_string_literal: true

module Poetry
  module Agent
    module Apps
      # One region's change: server-rendered HTML applied by the bridge to
      # the element whose `data-mcp-region` is the target, the way a Turbo
      # Stream applies to its target.
      class Fragment
        # The actions the bridge applies: replace the region's content,
        # append or prepend to it, or empty it.
        ACTIONS = %w[replace append prepend remove].freeze

        # The region's name.
        #
        # @return [String]
        attr_reader :target
        # The HTML, none for a remove.
        #
        # @return [String, nil]
        attr_reader :html
        # The action, one of {ACTIONS}.
        #
        # @return [String]
        attr_reader :action

        # A fragment for a region; the HTML comes with it or from a renderer.
        #
        # @param target [String] the region (`data-mcp-region`)
        # @param html [String, nil] the markup, none for a remove
        # @param action [Symbol, String] one of {ACTIONS}
        # @raise [ArgumentError] for an unknown action or a blank target
        def initialize(target:, html: nil, action: :replace)
          @target = target.to_s
          @html = html&.to_s
          @action = action.to_s
          raise ArgumentError, "a fragment needs a target region" if @target.empty?
          raise ArgumentError, "unknown fragment action #{@action.inspect}" unless ACTIONS.include?(@action)
          raise ArgumentError, "a #{@action} fragment needs html" if @html.nil? && @action != "remove"
        end

        # The wire shape.
        # @return [Hash]
        def to_h
          { "target" => target, "action" => action, "html" => html }.compact
        end
      end
    end
  end
end
