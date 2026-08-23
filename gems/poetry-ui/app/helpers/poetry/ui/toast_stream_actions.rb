# frozen_string_literal: true

module Poetry
  module Ui
    # The canonical server-side toast (the Toast contract's
    # Rails-native path):
    #
    #   turbo_stream.poetry_toast(title: "Saved", variant: :success)
    #   turbo_stream.poetry_toast(title: "Deleted") { |toast| toast.with_action { "Undo" } }
    #
    # An append into the data-turbo-permanent #poetry-toaster region -
    # usable from controller responses, form streams, and
    # Turbo::StreamsChannel.broadcast_append_to in jobs. Mixed into
    # Turbo::Streams::TagBuilder via the :turbo_streams_tag_builder load
    # hook (poetry-ui does not depend on turbo-rails; hosts that have it
    # get the action automatically - see the engine initializer).
    module ToastStreamActions
      def poetry_toast(title:, description: nil, target: Poetry::Ui::Toaster::Component::DEFAULT_ID, **)
        component = Poetry::Ui::Toast::Component.new(**)
        component.with_title { title }
        component.with_description { description } if description
        yield component if block_given?
        append(target, component)
      end
    end
  end
end
