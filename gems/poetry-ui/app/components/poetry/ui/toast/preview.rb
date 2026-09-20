# frozen_string_literal: true

module Poetry
  module Ui
    module Toast
      # The Toast preview matrix: every variant (each with its icon +
      # politeness derivation), the description pairing, the
      # action-bearing (persistent) undo shape, and a persistent error.
      class Preview < Poetry::Core::Preview::Base
        def default
          toast_example(:default, "Event scheduled", "Friday, July 10 at 5:00 PM")
        end

        def success
          toast_example(:success, "Changes saved", "Your profile has been updated.")
        end

        def info
          toast_example(:info, "Heads up", "A new version is available.")
        end

        def warning
          toast_example(:warning, "Storage almost full", "You have used 90% of your quota.")
        end

        # Destructive announces ASSERTIVELY (politeness derives from the
        # variant) - failures the user must hear about.
        def destructive
          toast_example(:destructive, "Payment failed", "Your card was declined.")
        end

        # An action-bearing toast defaults to PERSISTENT (duration nil ->
        # 0): a missable undo is a bug.
        # The promise-lifecycle opener: a spinning persistent toast the
        # job later REPLACES (turbo_stream.replace on its id) with the
        # settled success/destructive toast.
        def loading
          render_component(variant: :loading) do |toast|
            toast.with_title { "Creating event…" }
          end
        end

        def with_action
          render_component do |toast|
            toast.with_title { "Message deleted" }
            toast.with_action { "Undo" }
          end
        end

        # Explicit duration: 0 keeps a plain toast on screen until closed.
        def persistent
          render_component(variant: :destructive, duration: 0) do |toast|
            toast.with_title { "Sync failed" }
            toast.with_description { "Changes will retry when you're back online." }
          end
        end

        private

        def toast_example(variant, title, description)
          render_component(variant: variant) do |toast|
            toast.with_title { title }
            toast.with_description { description }
          end
        end
      end
    end
  end
end
