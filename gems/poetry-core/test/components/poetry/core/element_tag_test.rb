# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    # The element helper every template builds its elements through: it
    # renders what the Action View tag helpers render, and it is a call a
    # slot-compiling host leaves alone.
    class ElementTagTest < ViewComponent::TestCase
      module Probe
        class Component < Poetry::Core::Component
          attr_reader :build

          def initialize(build:, **)
            @build = build
            super(**)
          end

          def call = instance_exec(&build)
        end
      end

      ATTRIBUTES = { "data-slot" => "probe", "class" => "a b", "aria-hidden" => "true" }.freeze

      def test_a_block_form_renders_what_content_tag_renders
        ours = render_probe { element_tag(:button, **ATTRIBUTES) { "Save" } }
        theirs = render_probe { content_tag(:button, **ATTRIBUTES) { "Save" } }

        assert_equal theirs, ours
        assert_equal %(<button data-slot="probe" class="a b" aria-hidden="true">Save</button>), ours
      end

      def test_content_as_an_argument_renders_what_content_tag_renders
        ours = render_probe { element_tag(:span, "Title", "data-slot" => "title", class: "c") }
        theirs = render_probe { content_tag(:span, "Title", "data-slot" => "title", class: "c") }

        assert_equal theirs, ours
      end

      def test_attributes_given_as_a_hash_are_the_elements_attributes
        ours = render_probe { element_tag(:div, ATTRIBUTES) { "Body" } }

        assert_equal %(<div data-slot="probe" class="a b" aria-hidden="true">Body</div>), ours
      end

      def test_a_tag_name_held_in_a_variable_renders
        name = :h3
        rendered = render_probe { element_tag(name, "Title", class: "c") }

        assert_equal %(<h3 class="c">Title</h3>), rendered
      end

      def test_a_void_element_renders_what_tag_renders
        ours = render_probe { element_tag(:input, type: "hidden", name: "terms", value: "0", disabled: false) }
        theirs = render_probe { tag.input(type: "hidden", name: "terms", value: "0", disabled: false) }

        assert_equal theirs, ours
        assert_equal %(<input type="hidden" name="terms" value="0">), ours
      end

      def test_a_void_element_takes_its_attributes_as_a_hash_too
        ours = render_probe { element_tag(:input, { "type" => "text" }, name: "q") }

        assert_equal %(<input type="text" name="q">), ours
      end

      def test_a_view_has_the_helper_too
        view = vc_test_controller.view_context

        assert_equal %(<span class="c">Title</span>), view.element_tag(:span, "Title", class: "c")
      end

      # What the helper is for. With Action View's helpers resolved ahead of
      # the render, a splat never reaches the element and a tag name held in
      # a variable stops the template compiling; a helper Herb does not know
      # is compiled as the call it is.
      def test_herb_compiles_the_helper_as_a_call_when_it_resolves_tag_helpers
        require "herb"
        require "herb/engine"

        source = %(<%= element_tag(name, **attrs) do %>x<% end %>)
        compiled = Herb::Engine.new(source, parser_options: { action_view_helpers: true }, validate_ruby: true).src

        assert_includes compiled, "element_tag(name, **attrs) do"
      end

      private

      def render_probe(&build)
        render_inline(Probe::Component.new(build: build)).to_html
      end
    end
  end
end
