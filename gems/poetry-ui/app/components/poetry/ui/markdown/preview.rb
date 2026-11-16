# frozen_string_literal: true

module Poetry
  module Ui
    module Markdown
      # The Markdown preview: a reply rendered whole, the same reply cut
      # where a stream might cut it, and a reply inside a message.
      class Preview < Poetry::Core::Preview::Base
        REPLY = <<~MARKDOWN
          # Late orders

          Two orders are **late**, and one is *very* late. The check is `Order#late?`,
          and [the fulfilment guide](https://example.com/fulfilment) has the thresholds.

          1. ORD-1041, Lumen Labs
          2. ORD-1039, Gable & Sons

          ```ruby
          Order.processing.where(due_on: ...Date.current)
          ```

          | Order | Customer | Total |
          |:------|:---------|------:|
          | ORD-1041 | Lumen Labs | $482.50 |
          | ORD-1039 | Gable & Sons | $2,040.00 |

          > ORD-1041 ships ~~today~~ tomorrow.
        MARKDOWN

        # The reply as far as a stream has written it: inside a bold
        # phrase, one row into a second table.
        WRITTEN = "#{REPLY}\nThe totals by warehouse, **as of this mor".freeze

        def default
          render_component(text: REPLY, heading_level: 3, class: "max-w-xl")
        end

        # The marks the last block has left open are closed for display.
        def streaming
          render_component(text: WRITTEN, streaming: true, heading_level: 3, class: "max-w-xl")
        end

        # A reply that cites its sources: each [n] is a citation linked to
        # the source it numbers, and the list sits under the reply (a
        # per-example template: two components and their sources).
        def with_sources
          render_with_template(template: "poetry/ui/markdown/with_sources_preview")
        end

        # A reply in a transcript: a ghost bubble lets the prose run the
        # row's width (a per-example template: nested components need a
        # view context).
        def in_a_message
          render_with_template(template: "poetry/ui/markdown/in_a_message_preview")
        end
      end
    end
  end
end
