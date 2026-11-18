# frozen_string_literal: true

module Poetry
  module Motion
    module Background
      # A decorative background behind its content, all CSS: a grid or dot
      # pattern, and optionally an effect (aurora, meteors, a retro grid,
      # ripples), faded at the edges. No script and no engine. Every layer
      # is server-rendered, aria-hidden and placed deterministically; reduced
      # motion stills the effect and keeps the pattern.
      #
      # @example A hero over a faded dot grid with meteors
      #   <%= poetry_background(pattern: :dots, effect: :meteors, fade: :radial, class: "py-24") do %>
      #     <h1>...</h1>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Motion::Options

        # The patterns the background can draw.
        PATTERNS = %i[none grid dots].freeze
        # The effects the background can run.
        EFFECTS = %i[none aurora meteors retro_grid ripple].freeze
        # How the decoration fades toward the edges.
        FADES = %i[none radial bottom].freeze

        AGENT_RULES = [
          "Backgrounds are decoration: text on them still meets contrast, and the content stands on its " \
          "own with the background removed.",
          "This is the CSS tier: a background that follows the pointer, draws on a canvas or runs a " \
          "shader is not this component."
        ].freeze

        motion_options
        option :pattern, :symbol, default: :grid, doc: "The pattern: none, grid or dots."
        option :effect, :symbol, default: :none, doc: "The effect: none, aurora, meteors, retro_grid or ripple."
        option :fade, :symbol, default: :radial, doc: "How the decoration fades: none, radial or bottom."
        option :count, :integer, default: 12, doc: "How many meteors or rings the effect draws."

        validates :pattern, inclusion: { in: PATTERNS }
        validates :effect, inclusion: { in: EFFECTS }
        validates :fade, inclusion: { in: FADES }

        part "background", "The region; the decoration sits behind its content",
             states: { "data-pattern" => { condition: "always - the pattern", values: PATTERNS.map(&:to_s) },
                       "data-effect" => { condition: "always - the effect", values: EFFECTS.map(&:to_s) },
                       "data-fade" => { condition: "always - the edge fade", values: FADES.map(&:to_s) },
                       "data-animate" => "present as false when the effect is still (animate: false)" }
        part "background-layer", "The decoration behind the content, aria-hidden"
        part "background-particle", "One meteor or ring of the effect",
             vars: { "--particle-index" => "its place among the effect's particles",
                     "--particle-x" => "its horizontal start, in percent",
                     "--particle-delay" => "its delay, in seconds" }

        def before_render
          ensure_within!(:count, 1..40)
        end

        def call
          tag.div(**root_attributes) do
            safe_join([layer, (tag.div(content, class: css(:content)) if content.present?)].compact)
          end
        end

        def root_attributes
          attrs = { "data-pattern" => pattern, "data-effect" => effect, "data-fade" => fade }
          attrs["data-animate"] = "false" unless animate
          super(attrs)
        end

        private

        def layer
          tag.div("aria-hidden" => "true", "data-slot" => "background-layer", class: css(:layer)) do
            safe_join(particles)
          end
        end

        # Meteors and ripple rings, placed by index so every render is the same.
        def particles
          return [] unless %i[meteors ripple].include?(effect)

          Array.new(count) do |index|
            x = ((index * 37) + 11) % 100
            delay = ((index * 0.73) % 6).round(2)
            tag.span("data-slot" => "background-particle",
                     style: "--particle-index: #{index}; --particle-x: #{x}%; --particle-delay: #{delay}s")
          end
        end
      end
    end
  end
end
