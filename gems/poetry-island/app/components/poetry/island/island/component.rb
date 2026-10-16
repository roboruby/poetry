# frozen_string_literal: true

module Poetry
  module Island
    module Island
      # A bounded client mount inside server-rendered HTML: the one place in
      # a Poetry page where the client owns the state, for a widget that
      # changes it many times a second (an editor, a canvas, a map, a 3D
      # scene). The block is the shell, what the page shows before the
      # module mounts and whenever it cannot. The module, an importmap
      # specifier exporting mount(element, props), mounts beside the shell
      # when the island connects and unmounts when it disconnects; a morph
      # refresh keeps the island and hands it the server's new props. State
      # that must outlive the page leaves through the form: name: renders a
      # hidden input inside the island for the module to write to.
      #
      # @example A map that paints the shell's box
      #   <%= poetry_island(import: "islands/map", props: { center: [lat, lng] }, class: "h-80") do %>
      #     <%= image_tag "office-map.png", alt: "The office, on a map" %>
      #   <% end %>
      # @example An editor that takes the shell's place and submits with the form
      #   <%= poetry_island(import: "islands/editor", mode: :flow, name: "post[body]", value: @post.body) do %>
      #     <%= sanitize(@post.body) %>
      #   <% end %>
      class Component < Poetry::Core::Component
        MODES = %i[fill flow].freeze

        AGENT_RULES = [
          "An island is the exception, for client-owned state that changes many times a second (an editor, a " \
          "canvas, a map, a 3D scene); anything else is a component with a Stimulus behavior.",
          "The block is the shell: what a reader gets before the module mounts and whenever it cannot, and in " \
          "fill mode the box the island paints. Put the content a reader needs there, never nothing.",
          "State that must outlive the page leaves through the form: name: renders a hidden input inside the " \
          "island, and the module writes to props.input.",
          "import: is an importmap specifier the host pins (app/javascript/islands/map.js is islands/map); " \
          "poetry check warns when config/importmap.rb does not."
        ].freeze

        # The full identifier: a short :island would be ambiguous next to a
        # host or community controller of the same suffix.
        use_stimulus do
          on :root do
            controller :"poetry--island--island" do
              register
              value :import
              value :mode
            end
          end
          on :shell do
            controller(:"poetry--island--island") { target :shell }
          end
          on :input do
            controller(:"poetry--island--island") { target :input }
          end
        end

        option :import, :string, required: true,
                                 doc: "The importmap specifier of the island's module, which exports " \
                                      "mount(element, props)."
        option :props, ActiveModel::Type::Value.new, default: {},
                                                     doc: "What the module mounts with, a Hash serialized as JSON."
        option :mode, :symbol, default: :fill,
                               doc: "fill paints the shell's box (a canvas, a map, a scene); flow takes the " \
                                    "shell's place in the page (an editor)."
        option :name, :string, doc: "A form field name: renders a hidden input inside the island, props.input, " \
                                    "for the module to write its state to."
        option :value, :string, doc: "The hidden input's initial value."

        validates :mode, inclusion: { in: MODES }

        part "island", "The island: the shell, the hidden input, the props, then the root the module mounts in"
        part "island-shell", "The server-rendered content the island takes over"
        part "island-input", "The hidden input the module writes its state to, with name:"

        def before_render
          raise ArgumentError, "island props: takes a Hash (got #{props.inspect})" unless props.is_a?(Hash)
          raise ArgumentError, "island value: needs name:, the hidden input it fills" if value && name.blank?
        end

        private

        # The shell's classes: hidden under a mounted flow island, invisible
        # with its box kept under a fill one.
        def shell_classes
          class_names(css(:shell), mode == :flow ? css(:shell_flow) : css(:shell_fill))
        end

        # The props as a JSON script's content: no <, > or & survives, so a
        # closing script tag inside a value cannot end the script early.
        def props_json = ERB::Util.json_escape(props.to_json).html_safe
      end
    end
  end
end
