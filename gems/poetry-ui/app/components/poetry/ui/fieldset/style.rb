# frozen_string_literal: true

module Poetry
  module Ui
    module Fieldset
      # Upstream FieldSet/FieldLegend/FieldDescription structure; the
      # group rhythm (gaps, legend margins, type scale) rides the theme.
      # :hint wears cn-field-description - the same style hook as Field's
      # hint, so one theme rule styles description text across the family.
      class Style < Poetry::Core::Style
        base "cn-field-set flex flex-col"

        element :legend, "cn-field-legend"
        element :hint, "cn-field-description"
      end
    end
  end
end
