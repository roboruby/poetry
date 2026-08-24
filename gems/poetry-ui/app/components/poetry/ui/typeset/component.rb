# frozen_string_literal: true

module Poetry
  module Ui
    # Prose containers for rendered markdown.
    module Typeset
      # The prose container for rendered markdown and other element-soup
      # HTML: every bare heading, paragraph, list, and table inside is
      # styled by the app-owned typeset.css the installer copies. Three
      # rhythm variables (size / leading / flow) drive the scale -
      # everything else derives - and preset: appends a tiny app-defined
      # class that retunes them. Opt an embedded component's subtree out
      # with class: "not-typeset"; wrap a wide block in a typeset-scroll
      # div to scroll horizontally instead of compressing.
      #
      # @example
      #   render Poetry::Ui::Typeset::Component.new(preset: "docs") do
      #     @article_html
      #   end
      class Component < Poetry::Core::Component
        requires_content "the rendered prose HTML"

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Wrap RENDERED markdown / prose HTML (headings, paragraphs, lists, tables) - never app " \
          "chrome; poetry components style themselves.",
          "preset: \"docs\" appends typeset-docs - a preset is a tiny class in the app's own CSS " \
          "setting --typeset-size/-leading/-flow (and font vars).",
          "Opt an embedded component OUT of the prose styling with class: \"not-typeset\" - it " \
          "covers the whole subtree.",
          "Wrap a wide table (or any wide block) in a typeset-scroll div inside the prose to " \
          "scroll horizontally instead of compressing."
        ].freeze

        # Appends typeset-<preset> - a tiny class in the app's own CSS
        # retuning the rhythm variables (e.g. "docs").
        option :preset, :string

        part "typeset", "The prose container - every bare element inside is styled by the " \
                        "app-owned typeset.css; not-typeset (class or data attribute) opts a " \
                        "subtree out"

        # @api private
        def before_render
          ensure_content!
        end

        # @api private
        def call
          content_tag(:div, content, **root_attributes.to_attributes)
        end

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "typeset" }.merge(component_data_attributes)
          )
        end

        # The preset rides the root class list (the caller's class: still
        # wins conflicts through the merger, as everywhere).
        # @api private
        def css(element = nil, **options)
          return super unless element.nil?

          classnames(super, ("typeset-#{preset}" if preset.present?))
        end
      end
    end
  end
end
