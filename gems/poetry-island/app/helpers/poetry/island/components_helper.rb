# frozen_string_literal: true

module Poetry
  module Island
    # The view helper for poetry-island, included into every view by the
    # engine.
    module ComponentsHelper
      # A bounded client mount inside server-rendered HTML.
      def poetry_island(**, &) = render(Poetry::Island::Island::Component.new(**), &)
    end
  end
end
