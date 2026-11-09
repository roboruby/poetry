# frozen_string_literal: true

require "test_helper"

module Poetry
  module Island
    # The island renders its shell, its props and its wiring on the server;
    # the controller does the rest in the browser.
    class IslandTest < ViewComponent::TestCase
      def test_renders_the_shell_the_props_script_and_the_wiring
        render_inline(Island::Component.new(import: "islands/map", props: { zoom: 12, tiles: %w[a b] })) do
          "<p>A map</p>".html_safe
        end
        root = page.find("[data-slot=island]")

        assert_equal "poetry--island--island", root["data-controller"]
        assert_equal "islands/map", root["data-poetry--island--island-import-value"]
        assert_equal "fill", root["data-poetry--island--island-mode-value"]
        shell = root.find("[data-slot=island-shell]")

        assert_equal "shell", shell["data-poetry--island--island-target"]
        assert_includes shell["class"], "[[data-island-mounted]>&]:invisible"
        assert_equal "A map", shell.find("p").text
        script = root.find("script[type='application/json']", visible: :all)

        assert_equal({ "zoom" => 12, "tiles" => %w[a b] }, JSON.parse(script.native.inner_html))
        assert_no_selector "[data-slot=island-input]"
      end

      def test_a_flow_island_hides_its_shell_once_mounted
        render_inline(Island::Component.new(import: "islands/editor", mode: :flow)) { "x" }

        assert_equal "flow", page.find("[data-slot=island]")["data-poetry--island--island-mode-value"]
        assert_includes page.find("[data-slot=island-shell]")["class"], "[[data-island-mounted]>&]:hidden"
      end

      def test_name_renders_the_hidden_input_inside_the_island
        render_inline(Island::Component.new(import: "islands/editor", mode: :flow, name: "post[body]",
                                            value: "<p>Hi</p>")) { "x" }
        input = page.find("[data-slot=island] > input[data-slot=island-input]", visible: :all)

        assert_equal "hidden", input["type"]
        assert_equal "post[body]", input["name"]
        assert_equal "<p>Hi</p>", input["value"]
        assert_equal "input", input["data-poetry--island--island-target"]
      end

      # The props script's content is JSON with its angle brackets and
      # ampersands escaped, so a closing script tag inside a value cannot
      # end the script early.
      def test_the_props_script_cannot_be_closed_from_inside
        render_inline(Island::Component.new(import: "islands/x", props: { html: "</script><b>&</b>" }))
        source = page.find("script[type='application/json']", visible: :all).native.inner_html

        refute_includes source, "</script>"
        assert_equal({ "html" => "</script><b>&</b>" }, JSON.parse(source))
      end

      def test_validates_mode_props_and_the_value_without_a_name
        assert_raises(ActiveModel::ValidationError, ArgumentError) do
          render_inline(Island::Component.new(import: "islands/x", mode: :float))
        end
        assert_raises(ArgumentError) { render_inline(Island::Component.new(import: "islands/x", props: [1])) }
        assert_raises(ArgumentError) { render_inline(Island::Component.new(import: "islands/x", value: "v")) }
        assert_raises(ArgumentError, ActiveModel::ValidationError) { render_inline(Island::Component.new) }
      end

      def test_the_helper_renders_the_component
        html = ApplicationController.render(inline: '<%= poetry_island(import: "islands/x") { "shell" } %>')

        assert_includes html, 'data-slot="island"'
        assert_includes html, "shell"
      end
    end
  end
end
