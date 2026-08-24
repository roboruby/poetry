# frozen_string_literal: true

module Poetry
  module Ui
    module TagGroup
      # The TagGroup - a removable-chip
      # collection: recipients, filters, labels. Grid semantics (container
      # role=grid, each tag role=row > gridcell), one Tab stop with roving
      # arrows (wrapping, horizontal), Delete/Backspace removes the focused
      # tag, each remove button removes exactly its own, and focus recovers
      # forward-then-backward (the container takes over when the last tag
      # goes - role flips to group). The container is a live region only
      # while focus is within. Form mode: name: serializes one hidden
      # name[] input per tag; removal is CANCELABLE
      # (poetry:tag-group:remove) for Turbo-owned re-renders.
      #
      # Documented divergence from the source tag contract: selection modes
      # are DEFERRED - poetry tags are removal-first (the toggle-a-choice
      # job belongs to ToggleGroup; the pick-from-options job to Combobox
      # multiple, whose chips these visually match).
      #
      # @example Removable recipients that submit as recipients[]
      #   render Poetry::Ui::TagGroup::Component.new(label: "Recipients", name: "recipients") do |group|
      #     group.with_tag(value: "ada", label: "Ada")
      #     group.with_tag(value: "grace", label: "Grace")
      #   end
      class Component < Poetry::Core::Component
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

        renders_many :tags, lambda { |value:, label: nil, disabled: false, removable: true, **options, &block|
          tag_row(value: value, label: label, disabled: disabled, removable: removable, **options, &block)
        }

        # BOTH controllers declare on the grid element - the one-Attributes
        # rule holds by construction; roving-focus owns the arrow keys with
        # the group's own keydown layered on the same event.
        use_stimulus do
          on :grid do
            controller :tag_group do
              register
              action :keydown, on: :keydown
            end
            controller :roving_focus do
              register
              value :orientation, :horizontal
              value :loop, true
              action :keydown, on: :keydown
            end
          end
          on :remove do
            controller(:tag_group) { action :remove, on: :click }
          end
        end

        option :name, :string
        option :label, :string, required: true
        # Space-separated hint/error ids for the GRID (the labelled element) -
        # a raw aria-describedby in html_attributes would land on the outer
        # wrapper div, unassociated for AT.
        option :described_by, :string

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

        def before_render
          raise ArgumentError, "TagGroup requires label: (the grid's accessible name)" if label.blank?
        end

        # The scoped-descendant pattern: one instance id (ladder: caller
        # id -> key -> random), every inner id derives from it - so a
        # keyed group's label AND rows are all morph-stable, and rows
        # never touch a group-level allocator.
        def instance_id
          @instance_id ||= poetry_instance_id("poetry-tag-group")
        end

        def label_id
          "#{instance_id}-label"
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
            **(described_by.present? ? { "aria-describedby" => described_by } : {}),
            # Polite only while focus is within (controller-flipped): SRs
            # hear tags added mid-work without spam from elsewhere.
            "aria-live" => "off",
            "aria-atomic" => "false",
            "aria-relevant" => "additions"
          }
          attrs["data-empty"] = "" if tags.none?
          attrs["tabindex"] = "0" if tags.none?
          attrs.merge(stimulus_attributes_for(:grid))
        end

        # Built here (not in the template) so the slot lambda can compose
        # the full row - content, remove button, hidden input - around the
        # consumer's block.
        def tag_row(value:, label:, disabled:, removable:, **options, &block)
          # Rows are the reorderable collection: identity derives from
          # value: (the collection contract - unique within the group),
          # namespaced under the group's instance id so two groups with
          # the same tag values never collide.
          row_id = options[:id].presence ||
                   "#{instance_id}-tag-#{Poetry::Core::StableId.key_token(value) || SecureRandom.hex(8)}"
          attrs = {
            "id" => row_id, "role" => "row", "data-slot" => "tag-group-tag",
            "data-value" => value, "data-poetry-collection-item" => "",
            "aria-label" => label || value.to_s,
            "tabindex" => "-1", "class" => css(:tag)
          }
          attrs["data-disabled"] = "" if disabled

          # Caller options ride along (they were silently discarded before);
          # data-value is RESERVED - the row's collection identity comes
          # from value:, any caller spelling loses.
          options.delete(:"data-value")
          options.delete("data-value")
          merged = Poetry::Core::HTML::Attributes.merged(attrs, options.except(:id))
          merged["data-value"] = value

          content_tag(:div, merged) do
            content_tag(:span, { "role" => "gridcell", "class" => css(:cell) }) do
              safe_join([
                # label: doubles as the visible content when no block is
                # given (the builder's model-array path renders text-only).
                block ? capture(&block) : label.to_s,
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

          content_tag(:button, attrs.merge(stimulus_attributes_for(:remove))) do
            render(Icon::Component.new(name: :x))
          end
        end

        def hidden_input(value)
          tag.input(type: "hidden", name: "#{name}[]", value: value)
        end
      end
    end
  end
end
