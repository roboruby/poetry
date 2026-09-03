# frozen_string_literal: true

module Poetry
  module SimpleForm
    module Inputs
      # string/email/url/tel/search/citext: the resolved simple_form
      # input_type IS poetry's as: vocabulary (citext folds to string).
      class StringInput < Base
        private

        def poetry_as
          # :string is simple_form's no-column fallback (ActiveModel,
          # virtual attributes) - hand poetry a nil so ITS inference runs
          # (type_for_attribute + name heuristics); a concretely resolved
          # type passes through.
          return nil if %i[string citext uuid].include?(input_type)

          input_type
        end
      end
    end
  end
end
