# frozen_string_literal: true

module Poetry
  module Ui
    module Carousel
      # The Carousel - slides on the PLATFORM's scroll-snap (the W4
      # decision: no embla): the viewport is a real scroll container (touch,
      # momentum, snapping for free), and poetry--core--carousel adds
      # prev/next paging, button state, and arrow keys. Declare slides with
      # with_item; the component owns the region/slide ARIA and the
      # controls.
      #
      # Deferred with embla's machinery: loop, autoplay, plugins.
      class Component < Poetry::Core::Component
        ORIENTATIONS = %i[horizontal vertical].freeze

        AGENT_RULES = [
          "label: is REQUIRED - the carousel region's accessible name.",
          "Declare slides with with_item - the component stamps the slide roles " \
          "(role=group + aria-roledescription=slide).",
          "Slides are REAL scroll content: they stay reachable by swipe, wheel, and keyboard even " \
          "before JS - never gate content behind the buttons alone.",
          "Size slides with item classes (basis-full default; basis-1/3 for a strip)."
        ].freeze

        CONTROLLER = %i[poetry core carousel].freeze

        # required: the hand raise in before_render carries the message;
        # the flag carries the fact to the registry (: the floating
        # crash - a required option the static tier could not see).
        option :label, :string, required: true
        option :orientation, :symbol, default: :horizontal
        option :show_controls, :boolean, default: true

        validates :orientation, inclusion: { in: ORIENTATIONS }

        part "carousel", "The role=region root - the controller (paging, button state, arrow keys) " \
                         "rides here",
             states: {
               "data-orientation" => { condition: "the scroll axis", values: ORIENTATIONS.map(&:to_s) }
             }
        part "carousel-content", "The viewport - a real scroll-snap container (tabindex=0); the " \
                                 "platform owns the physics"
        part "carousel-item", "One role=group slide - sized by item classes (basis-full default)"

        Slide = Data.define(:classes, :block)

        # The lambda's raise, declared (the SLOT_BUILDERS pattern): poetry
        # check states the same requirement statically.
        SLOT_REQUIRED_CONTENT = { item: "the slide" }.freeze

        renders_many :items, lambda { |classes: nil, &block|
          raise ArgumentError, "Carousel with_item requires a content block (the slide)" unless block

          slides << Slide.new(classes: classes, block: block)
          nil
        }

        def slides
          @slides ||= []
        end

        # The same facts the before_render raise enforces, stated statically
        #: poetry check flags the omission without rendering (the
        # menu crash class - required slots the contract kept silent).
        REQUIRED_SLOTS = { item: "at least one slide" }.freeze

        def before_render
          raise ArgumentError, "Carousel requires label: (the region's accessible name)" if label.blank?
          raise ArgumentError, "Carousel requires at least one with_item" unless items?
        end

        def vertical? = orientation == :vertical

        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "role" => "region", "aria-roledescription" => "carousel", "aria-label" => label,
              "data-slot" => "carousel", "data-orientation" => orientation
            }.merge(root_stimulus_attributes).merge(component_data_attributes)
          )
        end

        def viewport_attributes
          {
            "data-slot" => "carousel-content",
            # A REAL scroll region must be keyboard-reachable (the ScrollArea
            # rule); the arrows then page it via the root's keydown.
            "tabindex" => "0",
            "class" => "#{css(:content)} #{css(vertical? ? :content_vertical : :content_horizontal)}"
          }.merge(viewport_stimulus_attributes)
        end

        def item_attributes(slide)
          {
            "role" => "group", "aria-roledescription" => "slide", "data-slot" => "carousel-item",
            "class" => [css(:item), css(vertical? ? :item_vertical : :item_horizontal),
                        slide.classes].compact.join(" ")
          }
        end

        def control_options(direction)
          {
            variant: :outline, size: :"icon-sm",
            label: direction == :previous ? "Previous slide" : "Next slide",
            class: "#{css(:control)} #{css(:"control_#{direction}_#{orientation}")}",
            data: {
              slot: "carousel-#{direction == :previous ? "previous" : "next"}",
              "poetry--core--carousel-target": direction == :previous ? "previous" : "next",
              action: "click->poetry--core--carousel##{direction == :previous ? "previous" : "next"}"
            }
          }
        end

        private

        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          carousel = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          carousel.register_controller
          carousel.with_value(:orientation, orientation)
          carousel.with_action(:keydown, on: :keydown)
          attrs.to_attributes
        end

        def viewport_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          carousel = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          carousel.with_target(:viewport)
          carousel.with_action(:scrolled, on: :scroll)
          attrs.to_attributes
        end
      end
    end
  end
end
