# frozen_string_literal: true

module Poetry
  module Core
    class Style
      include ClassVariants::Helper

      # https://tailwindcss.com/docs/colors
      COLORS = %i[
        red
        orange
        amber
        yellow
        lime
        green
        emerald
        teal
        cyan
        sky
        blue
        indigo
        violet
        purple
        fuchsia
        pink
        rose
        slate
        gray
        zinc
        neutral
        stone
      ].freeze

      # https://tailwindcss.com/docs/fill
      FILLS = %i[
        none
        inherit
        current
        transparent
        black
        white
      ].freeze

      # TODO: Move to engine initializer
      ClassVariants.configuration.process_classes_with do |classes|
        TailwindMerge::Merger.new.merge(classes)
      end

      class << self
        def css(...)
          new.css(...)
        end
      end

      def css(...)
        instance.render(...).strip
      end

      def instance
        self.class.singleton_class.instance_variable_get(:@_class_variants_instance)
      end

      def bases
        instance.instance_variable_get(:@bases)
      end

      def variants
        instance.instance_variable_get(:@variants)
      end

      def defaults
        instance.instance_variable_get(:@defaults)
      end

      def variant_options(slot = :default)
        variants
          .select { |variant| variant[:slot] == slot }
          .reject { |variant| variant.size > 3 }
          .group_by { |variant| variant.keys.find { |k| k != :class && k != :slot } }
          .transform_values { |arr| arr.map { |v| v.keys.find { |k| k != :class && k != :slot } }.uniq }
          .transform_values.with_index do |_, idx|
            arr = variants.select { |v| v[:slot] == slot }
            key = arr.map { |v| v.keys.find { |k| k != :class && k != :slot } }.uniq[idx]
            arr.select { |v| v.key?(key) }.map { |v| v[key] }.uniq
          end
      end
    end
  end
end
