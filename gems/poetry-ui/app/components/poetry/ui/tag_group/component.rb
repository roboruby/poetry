# frozen_string_literal: true

module Poetry
  module Ui
    module TagGroup
      # The TagGroup (the react-aria tag contract): a removable-chip
      # collection - recipients, filters, labels. Grid semantics (container
      # role=grid, each tag role=row > gridcell), one Tab stop with roving
      # arrows (wrapping, horizontal), Delete/Backspace removes the focused
      # tag, each remove button removes exactly its own, and focus recovers
      # forward-then-backward (the container takes over when the last tag
      # goes - role flips to group). The container is a live region only
      # while focus is within. Form mode: name: serializes one hidden
      # name[] input per tag; removal is CANCELABLE
      # (poetry:tag-group:remove) for Turbo-owned re-renders.
      #
      # Documented divergence from react-aria: selection modes are
      # DEFERRED - poetry tags are removal-first (the toggle-a-choice job
      # belongs to ToggleGroup; the pick-from-options job to Combobox
      # multiple, whose chips these visually match).
      class Component < Poetry::Core::Component
        CONTROLLER = %i[poetry core tag_group].freeze
        ROVING = %i[poetry core roving_focus].freeze

        AGENT_RULES = [
          "Removable chips are a TagGroup - never hand-rolled badges with x buttons; removal " \
          "keyboard (Delete/Backspace), focus recovery, and the live region ride the controller.",
          "label: is REQUIRED (the grid's accessible name, rendered as a caption span).",
          "name: turns the group into a form value - one hidden <name>[] input per tag " \
          "submits; removing a tag removes its input.",
          "Removal is cancelable: listen for poetry:tag-group:remove and preventDefault to " \
          "own the removal server-side (Turbo re-render).",
          "Choosing from options is Combobox multiple; toggling fixed choices is ToggleGroup - " \
          "a TagGroup holds items that exist until removed."
        ].freeze

        option :name, :string
        option :label, :string, required: true

        part "tag-group", "The labelled wrapper - caption span + grid stack here"
        part "tag-group-label", "The caption span (label:), wired via aria-labelledby (a grid " \
                                "is not a labelable form control - never a <label>)"
        part "tag-group-grid", "The tag collection (role=grid; role=group + the tab stop when " \
                               "empty) - roving focus, removal keys, and the focus-scoped " \
                               "live region ride here",
             states: {
               "data-empty" => "no tags remain (controller-kept after removals)"
             }
        part "tag-group-tag", "One chip (role=row > gridcell): content, the remove button, " \
                              "and - in form mode - the hidden name[] input",
             states: {
               "data-disabled" => "the tag is disabled (skipped by arrows and removal)",
               "data-value" => { condition: "always - the tag's value (the remove event's " \
                                            "detail and the hidden input's value)" }
             }
        part "tag-group-remove", "The per-tag remove button - tabbable (Tab steps from the " \
                                 "row into it), removes exactly its own tag"

        renders_many :tags, lambda { |value:, text: nil, disabled: false, removable: true, **options, &block|
          tag_row(value: value, text: text, disabled: disabled, removable: removable, **options, &block)
        }

        def before_render
          raise ArgumentError, "TagGroup requires label: (the grid's accessible name)" if label.blank?
        end

        def label_id
          @label_id ||= "poetry-tag-group-label-#{SecureRandom.hex(4)}"
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "tag-group", "class" => css }.merge(component_data_attributes)
          )
        end

        def grid_attributes
          attrs = {
            "role" => tags.any? ? "grid" : "group",
            "data-slot" => "tag-group-grid",
            "class" => css(:grid),
            "aria-labelledby" => label_id,
            # Polite only while focus is within (controller-flipped): SRs
            # hear tags added mid-work without spam from elsewhere.
            "aria-live" => "off",
            "aria-atomic" => "false",
            "aria-relevant" => "additions"
          }
          attrs["data-empty"] = "" if tags.none?
          attrs["tabindex"] = "0" if tags.none?
          # BOTH controllers build into ONE Attributes object - a plain
          # hash merge would clobber the first data-controller token.
          attrs.merge(grid_stimulus_attributes)
        end

        # Built here (not in the template) so the slot lambda can compose
        # the full row - content, remove button, hidden input - around the
        # consumer's block.
        def tag_row(value:, text:, disabled:, removable:, **options, &block)
          row_id = options[:id].presence || "poetry-tag-#{SecureRandom.hex(4)}"
          attrs = {
            "id" => row_id, "role" => "row", "data-slot" => "tag-group-tag",
            "data-value" => value, "data-poetry-collection-item" => "",
            "aria-label" => text || value.to_s,
            "tabindex" => "-1", "class" => css(:tag)
          }
          attrs["data-disabled"] = "" if disabled

          content_tag(:div, attrs) do
            content_tag(:span, { "role" => "gridcell", "class" => css(:cell) }) do
              safe_join([
                capture(&block),
                (remove_button(row_id, disabled: disabled) if removable),
                (hidden_input(value) if name.present?)
              ].compact)
            end
          end
        end

        private

        def remove_button(row_id, disabled:)
          button_id = "#{row_id}-remove"
          attrs = {
            "type" => "button", "id" => button_id,
            "data-slot" => "tag-group-remove", "class" => css(:remove),
            # labelledby chains button -> row: "Remove, <tag name>".
            "aria-label" => t("poetry.tag_group.remove"),
            "aria-labelledby" => "#{button_id} #{row_id}"
          }
          attrs["disabled"] = "" if disabled

          content_tag(:button, attrs.merge(remove_stimulus_attributes)) do
            render(Icon::Component.new(name: :x))
          end
        end

        def hidden_input(value)
          tag.input(type: "hidden", name: "#{name}[]", value: value)
        end

        def grid_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          group = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          group.register_controller
          group.with_action(:keydown, on: :keydown)
          roving = Poetry::Core::Stimulus::Builder.new(ROVING, attrs)
          roving.register_controller
          roving.with_value(:orientation, :horizontal)
          roving.with_value(:loop, true)
          roving.with_action(:keydown, on: :keydown)
          attrs.to_attributes
        end

        def remove_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          group = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          group.with_action(:remove, on: :click)
          attrs.to_attributes
        end
      end
    end
  end
end
