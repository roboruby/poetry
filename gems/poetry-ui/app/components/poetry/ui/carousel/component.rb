# frozen_string_literal: true

module Poetry
  module Ui
    # Carousel family: the scroll-snap slide strip and its paging controls.
    module Carousel
      # A slide carousel on native scroll-snap: the viewport is a real
      # scroll container, so touch, momentum, and snapping work with no
      # JS, and prev/next paging plus arrow keys are layered on top.
      # Declare slides with with_item; the component owns the region and
      # slide ARIA and renders the controls.
      #
      # Looping, autoplay, and plugins are not supported.
      #
      # @example
      #   render Poetry::Ui::Carousel::Component.new(label: "Featured") do |carousel|
      #     carousel.with_item { "Slide one" }
      #     carousel.with_item { "Slide two" }
      #   end
      class Component < Poetry::Core::Component
        # The closed vocabulary for the orientation axis.
        ORIENTATIONS = %i[horizontal vertical].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "label: is REQUIRED - the carousel region's accessible name.",
          "Declare slides with with_item - the component stamps the slide roles " \
          "(role=group + aria-roledescription=slide).",
          "Slides are REAL scroll content: they stay reachable by swipe, wheel, and keyboard even " \
          "before JS - never gate content behind the buttons alone.",
          "Size slides with item classes (basis-full default; basis-1/2 lg:basis-1/3 for a gallery).",
          "Change slide spacing as a TRIO: track_classes: \"-ml-1\" plus item classes " \
          "\"pl-1 -scroll-ml-1\" - the gutter padding and its snap scroll-margin move together."
        ].freeze

        # States statically that with_item requires a content block, so
        # static checks can flag the omission without rendering.
        SLOT_REQUIRED_CONTENT = { item: "the slide" }.freeze

        # The required slots, stated statically so static checks can flag
        # a missing slide without rendering.
        REQUIRED_SLOTS = { item: "at least one slide" }.freeze

        # Declares one slide. The content block is required; classes: sizes
        # the slide (basis-full default).
        renders_many :items, lambda { |classes: nil, &block|
          raise ArgumentError, "Carousel with_item requires a content block (the slide)" unless block

          slides << Slide.new(classes: classes, block: block)
          nil
        }

        use_stimulus do
          on :root do
            controller :carousel do
              register
              value :orientation
              action :keydown, on: :keydown
            end
          end
          on :viewport do
            controller :carousel do
              target :viewport
              action :scrolled, on: :scroll
            end
          end
          # One element per control direction, forwarded into Button
          # kwargs (previously hand-written target + action strings).
          on :previous do
            controller :carousel do
              target :previous
              action :previous, on: :click
            end
          end
          on :next do
            controller :carousel do
              target :next
              action :next, on: :click
            end
          end
        end

        # The carousel region's accessible name - required; rendering
        # without it raises.
        option :label, :string, required: true
        # The scroll axis; snapping, controls, and arrow keys follow it.
        option :orientation, :symbol, default: :horizontal
        # Renders the prev/next buttons; slides stay reachable by swipe,
        # wheel, and keyboard without them.
        option :show_controls, :boolean, default: true
        # Utility classes for the slide track - change spacing as a trio:
        # track_classes: "-ml-1" pairs with item classes "pl-1 -scroll-ml-1".
        option :track_classes, :string

        validates :orientation, inclusion: { in: ORIENTATIONS }

        part "carousel", "The role=region root - the controller (paging, button state, arrow keys) " \
                         "rides here",
             states: {
               "data-orientation" => { condition: "the scroll axis", values: ORIENTATIONS.map(&:to_s) }
             }
        part "carousel-content", "The viewport - a real scroll-snap container (tabindex=0); the " \
                                 "platform owns the physics"
        part "carousel-item", "One role=group slide - sized by item classes (basis-full default)"

        # Enforces the required label and at least one slide.
        # @api private
        def before_render
          raise ArgumentError, "Carousel requires label: (the region's accessible name)" if label.blank?
          raise ArgumentError, "Carousel requires at least one with_item" unless items?
        end

        # The declared slides in render order.
        # @api private
        def slides
          @slides ||= []
        end

        # Whether the scroll axis is vertical.
        # @api private
        def vertical? = orientation == :vertical

        # Attributes for the role=region root.
        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "role" => "region", "aria-roledescription" => "carousel", "aria-label" => label,
              "data-slot" => "carousel", "data-orientation" => orientation
            }.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end

        # Attributes for the scroll-snap viewport.
        # @api private
        def viewport_attributes
          {
            "data-slot" => "carousel-content",
            # A REAL scroll region must be keyboard-reachable (the ScrollArea
            # rule); the arrows then page it via the root's keydown.
            "tabindex" => "0",
            "class" => "#{css(:content)} #{css(vertical? ? :content_vertical : :content_horizontal)}"
          }.merge(stimulus_attributes_for(:viewport))
        end

        # Attributes for one slide.
        # @api private
        def item_attributes(slide)
          # class: rides the merger so caller classes WIN on conflicts -
          # a raw join left basis-1/3 vs the dictionary's basis-full to
          # the compiled sheet's cascade order (which picked basis-full,
          # silently breaking the documented strip sizing).
          {
            "role" => "group", "aria-roledescription" => "slide", "data-slot" => "carousel-item",
            "class" => css(:item, class: [css(vertical? ? :item_vertical : :item_horizontal),
                                          slide.classes].compact)
          }
        end

        # Button options for one prev/next control.
        # @api private
        def control_options(direction)
          {
            variant: :outline, size: :"icon-sm",
            label: direction == :previous ? "Previous slide" : "Next slide",
            class: "cn-carousel-#{direction} #{css(:control)} #{css(:"control_#{direction}_#{orientation}")}",
            data: { slot: "carousel-#{direction == :previous ? "previous" : "next"}" }
          }.merge(stimulus_attributes_for(direction))
        end

        # One declared slide: its extra classes and content block.
        # @api private
        Slide = Data.define(:classes, :block)
      end
    end
  end
end
