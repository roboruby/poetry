# frozen_string_literal: true

require "active_model/type"

module ActiveModel
  module Type
    # The string type behind every `option :name, :string` declaration:
    # ActiveModel's String type copies each value into a fresh String,
    # which drops the html_safe mark a SafeBuffer carries, so a caller's
    # `hint: link_to(...)` or `t(".hint_html")` arrived escaped. This
    # type keeps an html-safe value as it is and casts everything else
    # exactly as the String type does; a plain String still escapes at
    # render, because nothing here marks anything safe.
    #
    # Substituted inside the option DSL only - never registered, so
    # `attribute :x, :string` in a host model keeps Rails' own type - and
    # it reports :string, so the registry and every introspection surface
    # read the declaration unchanged.
    class HtmlSafeString < ActiveModel::Type::String
      private

      # An html-safe String passes through untouched; everything else casts
      # as a String does.
      #
      # @param value [Object] the raw option value
      # @return [::String]
      def cast_value(value)
        return value if value.is_a?(::String) && value.html_safe?

        super
      end
    end
  end
end
