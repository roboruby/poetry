# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The declared-axis coverage gate: every symbol variant a
    # component declares must be RENDERED by at least one preview example.
    # The previews double as golden and axe fixtures, so a declared-but-
    # never-previewed variant is a state with zero visual and zero
    # accessibility coverage in every theme. Generalizes the Button-only
    # full-axis test in previews_test.rb to the whole registry roster.
    class PreviewCoverageTest < ViewComponent::TestCase
      # Records the resolved style values of every Poetry component that
      # renders while the sweep runs. Nested renders count - a Button
      # rendered inside an AlertDialog preview covers those Button values,
      # because that preview page is in the golden/axe walks too.
      module StyleRecorder
        RENDERED = Hash.new { |by_class, klass| by_class[klass] = Hash.new { |by_attr, attr| by_attr[attr] = Set.new } }

        class << self
          attr_accessor :active
        end

        def render_in(...)
          if StyleRecorder.active && self.class.respond_to?(:style_attributes)
            self.class.style_attributes.each do |attr|
              variants = self.class.try("#{attr}_variants")
              next unless variants.is_a?(Array)

              value = public_send(attr)
              RENDERED[self.class][attr] << value.to_sym unless value.nil?
            end
          end
          super
        end
      end

      Poetry::Core::Component.prepend(StyleRecorder)

      def test_every_declared_variant_renders_in_the_preview_corpus
        StyleRecorder.active = true
        registry_components.each do |key|
          preview = ViewComponent::Preview.find(key)

          assert preview, "no preview class for registry component #{key}"
          preview.examples.each do |example|
            render_preview(example, from: preview)
          rescue StandardError => e
            flunk "#{key}/#{example} failed to render in-process: #{e.class}: #{e.message}"
          end
        end
        StyleRecorder.active = false

        missing = registry_components.filter_map do |key|
          gaps = uncovered_axes(component_class(key))
          "#{key}: #{gaps.join("; ")}" unless gaps.empty?
        end

        assert_empty missing, <<~MSG
          Declared variants no preview example renders - these states have no
          golden and no axe coverage in any theme. Add a preview example (or
          drop the dead variant):
          #{missing.join("\n")}
        MSG
      end

      private

      # The registry is the roster, exactly as the golden/axe walks read it.
      def registry_components
        @registry_components ||= YAML.safe_load_file(
          Poetry::Ui.root.join("config/component_registry.yml")
        ).fetch("components").keys.sort
      end

      # Sidecar dirs are Name::Component; nested flat files (command/dialog)
      # are Name::NestedComponent.
      def component_class(key)
        "#{key.camelize}::Component".constantize
      rescue NameError
        "#{key.camelize}Component".constantize
      end

      # ["variant missing: link, ghost", ...] for every Array-variant axis
      # with declared values the sweep never saw rendered.
      def uncovered_axes(klass)
        klass.style_attributes.filter_map do |attr|
          variants = klass.try("#{attr}_variants")
          next unless variants.is_a?(Array)

          uncovered = variants.map(&:to_sym) - StyleRecorder::RENDERED[klass][attr].to_a
          "#{attr} missing: #{uncovered.join(", ")}" unless uncovered.empty?
        end
      end
    end
  end
end
