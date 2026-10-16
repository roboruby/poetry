# frozen_string_literal: true

module Poetry
  module Island
    module Island
      # The island as the server renders it: the shell a page shows before
      # the module mounts and whenever it cannot.
      class Preview < Poetry::Core::Preview::Base
        # A fill island: the shell sizes the box the module paints.
        def default
          render_component(import: "islands/map", props: { zoom: 12 },
                           class: "h-48 w-full max-w-md overflow-hidden rounded-xl border bg-muted") do
            '<p class="p-4 text-sm text-muted-foreground">The office, on a map once the island mounts.</p>'.html_safe
          end
        end

        # A flow island with a form field: the editor takes the shell's
        # place and writes to the hidden input.
        def flow
          render_component(import: "islands/editor", mode: :flow, name: "post[body]", value: "<p>Hello</p>",
                           class: "w-full max-w-md rounded-xl border p-3 text-sm") do
            "<p>Hello</p>".html_safe
          end
        end
      end
    end
  end
end
