# frozen_string_literal: true

module Poetry
  module Motion
    module Globe
      # Globe preview: three cities.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(markers: [[37.77, -122.42], [40.71, -74.0], [51.51, -0.13]], label: "Three offices")
        end
      end
    end
  end
end
