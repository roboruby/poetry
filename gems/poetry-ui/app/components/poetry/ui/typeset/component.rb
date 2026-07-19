# frozen_string_literal: true

module Poetry
  module Ui
    module Typeset
      # The Typeset (the shadcn/typeset port) - the prose container
      # for RENDERED markdown and other element-soup HTML. The styling lives
      # in the app-owned typeset.css the installer copies (three rhythm
      # variables - size / leading / flow - everything else derives);
      # this component is the wrapper contract: the .typeset switch, an
      # optional preset class, and the opt-out vocabulary.
      class Component < Poetry::Core::Component
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

        option :preset, :string

        part "typeset", "The prose container - every bare element inside is styled by the " \
                        "app-owned typeset.css; not-typeset (class or data attribute) opts a " \
                        "subtree out"

        requires_content "the rendered prose HTML"

        def before_render
          ensure_content!
        end

        def call
          content_tag(:div, content, **root_attributes.to_attributes)
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "typeset" }.merge(component_data_attributes)
          )
        end

        # The preset rides the root class list (the caller's class: still
        # wins conflicts through the merger, as everywhere).
        def css(element = nil, **options)
          return super unless element.nil?

          classnames(super, ("typeset-#{preset}" if preset.present?))
        end
      end
    end
  end
end
