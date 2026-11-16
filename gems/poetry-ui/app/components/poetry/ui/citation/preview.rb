# frozen_string_literal: true

module Poetry
  module Ui
    module Citation
      # The Citation preview: marks set in a sentence, and the number alone.
      class Preview < Poetry::Core::Preview::Base
        # Marks in prose, each a link named for its source (a per-example
        # template: the marks sit inside text).
        def default
          render_with_template(template: "poetry/ui/citation/default_preview")
        end

        # Without an address the mark is the number alone, as a sources
        # list shows it.
        def number_alone
          render_component(number: 3)
        end
      end
    end
  end
end
