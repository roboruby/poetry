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

        # @return [String] the region's name
        attr_reader :target
        # @return [String, nil] the HTML (none for remove)
        attr_reader :html
        # @return [String] the action
        attr_reader :action

        # @param target [String] the region (`data-mcp-region`)
        # @param html [String, nil] the HTML
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
