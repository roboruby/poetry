# frozen_string_literal: true

module Poetry
  module Charts
    module AdapterChart
      # The BYO-engine mount: the frame, the mount element, and the spec
      # JSON render server-side; the registered adapter draws client-side,
      # so previews show the served contract, not an engine's output.
      class Preview < Poetry::Core::Preview::Base
        DATA = [
          { month: "Jan", desktop: 186, mobile: 80 },
          { month: "Feb", desktop: 305, mobile: 200 },
          { month: "Mar", desktop: 237, mobile: 120 },
          { month: "Apr", desktop: 73, mobile: 190 }
        ].freeze

        CONFIG = {
          desktop: { label: "Desktop", color: "var(--chart-1)" },
          mobile: { label: "Mobile", color: "var(--chart-2)" }
        }.freeze

        def default
          render_component(type: :bar, engine: "chartjs", data: DATA, config: CONFIG,
                           series: [{ data_key: :desktop }, { data_key: :mobile }],
                           axes: { x: { data_key: :month } })
        end

        def labelled
          render_component(type: :line, engine: "chartjs", data: DATA, config: CONFIG,
                           series: [{ data_key: :desktop }],
                           axes: { x: { data_key: :month } },
                           id: "traffic", label: "Monthly desktop traffic")
        end
      end
    end
  end
end
