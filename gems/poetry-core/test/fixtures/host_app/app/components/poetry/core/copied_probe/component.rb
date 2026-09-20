# frozen_string_literal: true

# A gem component copied into the app (`poetry:add` places copies under
# the gem namespace): the gem registry already describes it, so host
# discovery must skip it.
module Poetry
  module Core
    module CopiedProbe
      class Component < Poetry::Core::Component
        def call
          content_tag(:span, content)
        end
      end
    end
  end
end
