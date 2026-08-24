# frozen_string_literal: true

module Poetry
  module Ui
    class FormBuilder < ActionView::Helpers::FormBuilder
      # The f.input inference pipeline,
      # vendored rather than integrated: `as:` wins,
      # then attachment duck-typing, AR enums, the model's attribute type,
      # and name heuristics on string columns. The resolver maps into
      # poetry's vocabulary (richer targets than the classic form DSLs
      # had: Combobox,
      # SensitiveInput, DatePicker), and the validator extractors turn
      # length/numericality/format validations into control attributes.
      module TypeInference
        # Name heuristics on string-typed attributes (the classic naming
        # regexes, trimmed to the ones poetry renders distinctly).
        STRING_HEURISTICS = {
          /password/ => :password,
          /email/ => :email,
          /\burl\b|_url\b/ => :url,
          /phone|\btel\b/ => :tel,
          /search|query/ => :search
        }.freeze

        # Model column type -> f.input control type.
        COLUMN_TYPES = {
          text: :text, boolean: :boolean, date: :date, time: :time,
          datetime: :datetime, integer: :number, float: :number,
          decimal: :number, string: :string
        }.freeze

        private

        def infer_input_type(method, collection: nil)
          return :select if collection
          return :file if attachment_attribute?(method)
          return :enum if enum_attribute?(method)

          column = column_type(method)
          if column == :string || column.nil?
            STRING_HEURISTICS.each { |pattern, type| return type if method.to_s.match?(pattern) }
          end
          COLUMN_TYPES.fetch(column, :string)
        end

        def attachment_attribute?(method)
          object.respond_to?("#{method}_attachment") || object.respond_to?("#{method}_attacher") ||
            object.respond_to?("remote_#{method}_url")
        end

        def enum_attribute?(method)
          object.class.respond_to?(:defined_enums) && object.class.defined_enums.key?(method.to_s)
        end

        def column_type(method)
          return nil unless object.class.respond_to?(:type_for_attribute)

          object.class.type_for_attribute(method.to_s)&.type
        end

        # -- validator extraction (the reflection tier) --------------------

        def validators_for(method)
          return [] unless object.class.respond_to?(:validators_on)

          object.class.validators_on(method)
        end

        # Length validation -> maxlength/minlength attributes.
        def length_attributes(method)
          validator = validators_for(method).find { |v| v.kind == :length }
          return {} unless validator

          attrs = {}
          max = validator.options[:maximum] || validator.options[:is]
          min = validator.options[:minimum] || validator.options[:is]
          attrs[:maxlength] = max if max
          attrs[:minlength] = min if min
          attrs
        end

        # Numericality -> min/max (greater_than folds to the next step).
        def numeric_attributes(method)
          validator = validators_for(method).find { |v| v.kind == :numericality }
          return {} unless validator

          options = validator.options
          step = options[:only_integer] ? 1 : nil
          gt = options[:greater_than]
          lt = options[:less_than]
          attrs = {
            min: options[:greater_than_or_equal_to] || (gt && step ? gt + step : gt),
            max: options[:less_than_or_equal_to] || (lt && step ? lt - step : lt)
          }
          attrs[:step] = step if step
          attrs.compact
        end

        # -- i18n (the poetry_form chain, reading simple_form keys too) ----

        # poetry_form.{kind}.{model}.{attribute} -> simple_form.* fallback
        # (free migration win: existing simple_form locales keep working).
        def form_i18n(kind, method)
          model_key = object.class.respond_to?(:model_name) ? object.class.model_name.i18n_key : nil
          return nil unless model_key

          %i[poetry_form simple_form].each do |namespace|
            value = I18n.t("#{namespace}.#{kind}.#{model_key}.#{method}", default: nil)
            value ||= I18n.t("#{namespace}.#{kind}.defaults.#{method}", default: nil)
            return value if value
          end
          nil
        end
      end
    end
  end
end
