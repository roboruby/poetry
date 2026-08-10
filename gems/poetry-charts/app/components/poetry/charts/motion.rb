# frozen_string_literal: true

module Poetry
  module Charts
    # Shared animation surface for the chart families: chart-level
    # options mirroring recharts' animation props (isAnimationActive /
    # animationDuration / animationEasing / animationBegin, defaults read
    # from the recharts v3 source per family), emitted as data-animate plus
    # --poetry-motion-* custom properties on the SVG. The animations
    # themselves are CSS (the motion stylesheet) and the A-W2 controller -
    # the server computes all geometry; the client only interpolates
    # between server-computed states.
    module Motion
      EASINGS = %i[ease linear ease_in ease_out ease_in_out].freeze
      CONTROLLER = "poetry--charts--motion"

      def self.included(base)
        base.extend(ClassMethods)

        # The motion controller rides the same frame element TooltipWiring
        # declares (include order IS emission order: tooltip, motion, then
        # live/window).
        base.use_stimulus do
          on :frame do
            controller(CONTROLLER, if: :animate?) { register }
          end
        end
      end

      module ClassMethods
        # Declares the animation options with the family's recharts
        # defaults (Bar 400ms, Pie begin 400ms, Scatter 400ms linear,
        # everything else 0/1500/ease).
        def motion_options(duration: 1500, delay: 0, easing: :ease)
          option :animate, :boolean, default: true
          option :animation_duration, :integer, default: duration
          option :animation_easing, :symbol, default: easing
          option :animation_begin, :integer, default: delay
        end
      end

      def animate?
        !!animate
      end

      # Merged into the SVG tag by TooltipWiring#svg_interaction_attributes.
      # Duration/begin are :integer-typed and easing is enum-validated, so
      # nothing user-controlled reaches the style attribute unguarded.
      def motion_svg_attributes
        return {} unless animate?

        { "data-animate" => "", "style" => motion_style }
      end

      def motion_style
        easing = animation_easing.to_sym
        raise ArgumentError, "unknown easing #{animation_easing.inspect}" unless EASINGS.include?(easing)

        style = "--poetry-motion-duration: #{animation_duration}ms; " \
                "--poetry-motion-easing: #{easing.to_s.tr("_", "-")}; " \
                "--poetry-motion-delay: #{animation_begin}ms"
        extra = motion_style_extras
        extra ? "#{style}; #{extra}" : style
      end

      # Hook: families append extra custom properties (radar ships the
      # polar center so CSS can scale from it).
      def motion_style_extras
        nil
      end

      # data-motion-sector: the server-computed sector params the A-W2
      # fan-out sweep reads (4-decimal formatting, matching sector_path's
      # own fmt so mid-sweep client paths stay byte-compatible).
      def motion_sector_value(cx, cy, inner, outer, start_angle, end_angle)
        [cx, cy, inner, outer, start_angle, end_angle]
          .map { |v| Geometry.js_number((v.to_f * 10_000).round / 10_000.0) }
          .join(" ")
      end
    end
  end
end
