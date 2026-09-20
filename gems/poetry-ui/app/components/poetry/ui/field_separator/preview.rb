# frozen_string_literal: true

module Poetry
  module Ui
    module FieldSeparator
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component
        end

        # The inline caption form - the line breaks around the text.
        def with_caption
          render_component { "Or continue with" }
        end
      end
    end
  end
end
