# frozen_string_literal: true

module Poetry
  module Agent
    module Apps
      # A UI tool's result: the text block every host shows a model, the
      # data in `structuredContent` (what a host with structured support
      # gives its model and the page), and the fragments in `_meta`, which
      # reach the page and stay out of the model's context.
      class Result
        # @return [String] the text content
        attr_reader :text
        # @return [Hash, nil] the structured content
        attr_reader :data
        # @return [Array<Fragment>] the fragments
        attr_reader :fragments
        # @return [Hash] the other `_meta` entries
        attr_reader :meta

        # @param text [String] the text content block
        # @param data [Hash, nil] `structuredContent`
        # @param fragments [Array<Fragment>] the fragments
        # @param error [Boolean] whether the result is an error
        # @param meta [Hash] more `_meta` entries (string keys)
        def initialize(text:, data: nil, fragments: [], error: false, meta: {})
          @text = text.to_s
          @data = data
          @fragments = Array(fragments)
          @error = error
          @meta = meta
        end

        # Whether the result is an error.
        # @return [Boolean]
        def error? = !!@error

        # The gem's response, as a tool block returns it.
        # @return [::MCP::Tool::Response]
        def to_response
          ::MCP::Tool::Response.new([{ type: "text", text: text }], structured_content: data, meta: to_meta,
                                                                    error: error?)
        end

        # The `_meta` entry: the fragments under {META_KEY}, beside the others.
        # @return [Hash, nil] nil when there is nothing to carry
        def to_meta
          entries = meta.dup
          entries[META_KEY] = { "fragments" => fragments.map(&:to_h) } if fragments.any?
          entries.empty? ? nil : entries
        end

        # The wire shape.
        # @return [Hash]
        def to_h = to_response.to_h
      end
    end
  end
end
