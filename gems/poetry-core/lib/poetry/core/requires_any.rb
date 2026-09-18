# frozen_string_literal: true

module Poetry
  module Core
    # The any-of contract of a registry entry (its requires_any groups): a
    # component that raises unless one of a content block, a slot or an
    # option is given. Phrased once here for poetry check, llms.txt and
    # the MCP server.
    module RequiresAny
      module_function

      # The group as a phrase naming the block, slots and options that satisfy it.
      #
      # @param group [Hash] one requires_any group: content, slots, options and hint
      # @return [String]
      def phrase(group)
        parts = []
        parts << "a content block" if group["content"]
        parts.concat((group["slots"] || []).map { |name| "with_#{name}" })
        parts.concat((group["options"] || []).map { |key| "#{key}:" })
        "one of #{parts.join(" / ")} (#{group["hint"]})"
      end
    end
  end
end
