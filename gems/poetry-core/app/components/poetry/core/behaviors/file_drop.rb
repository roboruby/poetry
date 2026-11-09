# frozen_string_literal: true

module Poetry
  module Core
    module Behaviors
      # Files arriving by drop, picker or paste (the file-drop controller):
      # the element is the drop target, the native file input inside it is
      # the form value, and every file is checked against accept, size and
      # count before it lands there. The controller reports each change
      # through its files event, with the accepted files and the rejected
      # ones by code, and the drag verdict through its drag event. Each
      # value is set only when the component passes it: `:option` reads
      # the component's own option, a Hash passes from:, anything else is
      # a literal.
      #
      # @example FileInput: the root takes drops for the input it wraps
      #   on(:root) { behavior :file_drop, accept: :option, multiple: :option, max_files: :option }
      module FileDrop
        extend Poetry::Core::Behavior

        behavior :file_drop, "Files arrive by drop, picker or paste and are checked against accept, size and " \
                             "count before they land in the native input."
        agent_rule "Client-side accept, size and count limits are advisory: validate the attachment on the " \
                   "model as well."

        # The values a component may set, in the order they declare.
        VALUES = %i[accept multiple max_files max_size min_size paste overlay directory prevent_document_drop
                    messages].freeze

        wiring do |**given|
          unknown = given.keys - VALUES
          raise ArgumentError, "unknown keywords: #{unknown.join(", ")}" if unknown.any?

          controller :file_drop do
            register
            VALUES.each { |name| behavior_value name, given[name] }
          end
        end
      end
    end
  end
end
