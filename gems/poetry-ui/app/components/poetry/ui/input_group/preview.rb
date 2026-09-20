# frozen_string_literal: true

module Poetry
  module Ui
    module InputGroup
      # The InputGroup preview: the search pattern (icon + control + kbd),
      # a button addon, and the block-aligned textarea form.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_with_template(template: "poetry/ui/input_group/search_preview")
        end

        def with_button
          render_with_template(template: "poetry/ui/input_group/button_preview")
        end

        def textarea_block
          render_with_template(template: "poetry/ui/input_group/textarea_preview")
        end
      end
    end
  end
end
