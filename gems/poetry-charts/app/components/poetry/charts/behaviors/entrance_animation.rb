# frozen_string_literal: true

module Poetry
  module Charts
    # The behaviors poetry-charts ships ({Poetry::Core::Behavior}).
    module Behaviors
      # A chart's entrance animation (the charts motion controller): the
      # client interpolates toward the server-computed geometry, and
      # reduced motion shows the finished chart. Wired only when the
      # chart's animate: option holds; the motion options come from
      # {Poetry::Charts::Motion}.
      module EntranceAnimation
        extend Poetry::Core::Behavior

        behavior :entrance_animation,
                 "Animates the chart in toward its server-computed geometry; reduced motion shows it finished."

        wiring do
          controller(Poetry::Charts::Motion::CONTROLLER, if: :animate?) { register }
        end
      end
    end
  end
end
