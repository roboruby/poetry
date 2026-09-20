# frozen_string_literal: true

require "test_helper"
require "json"
require "poetry/ui/dictionary_fidelity"

module Poetry
  module Ui
    # The dictionary-fidelity gate: every structural token a Style
    # dictionary puts on a part must match the styled source's className
    # for the same data-slot at the pin, or carry a receipt in
    # config/dictionary_fidelity/deviations.yml (exact, two-way - see
    # Poetry::Ui::DictionaryFidelity).
    #
    # Poetry's side is the rendered truth: every registry component's
    # previews, each owned element (PartContract's ownership rule) mapped
    # to its slot with the class tokens that belong to the dictionary. A
    # part rendered on another component's root (a composed Button) is
    # present but compares no tokens - that component's ledger covers them.
    #
    # DICTIONARY_REPORT=1 also writes every actual diff to
    # tmp/dictionary_fidelity/diffs.json for reconciliation scripts.
    class DictionaryFidelityTest < ViewComponent::TestCase
      ROOT = Poetry::Ui.root.to_s
      # Poetry components whose slots the source keeps in another file.
      SOURCE_FILE = {
        "command-dialog" => "command",
        "field-group" => "field",
        "field-separator" => "field",
        "fieldset" => "field",
        "toaster" => "toast",
        "toast-trigger" => "toast"
      }.freeze

      # Components rendering another component's dictionary verbatim (the
      # combobox embeds Command's anatomy): those tokens belong to the
      # universe too, or every reused part reads as bare.
      REUSES = { "combobox" => %w[command] }.freeze

      def test_every_dictionary_matches_its_source_slots_or_the_ledger
        rendered = rendered_slots
        if ENV["DICTIONARY_REPORT"]
          dir = File.join(ROOT, "tmp/dictionary_fidelity")
          FileUtils.mkdir_p(dir)
          diffs = DictionaryFidelity.current_diffs(ROOT, rendered)
          diffs["elements"] = @slot_elements
          File.write(File.join(dir, "diffs.json"), JSON.pretty_generate(diffs))
        end
        findings = DictionaryFidelity.verify(ROOT, rendered)

        assert_empty findings, "#{findings.length} dictionary-fidelity finding(s):\n\n#{findings.join("\n")}"
      end

      private

      # source file key => slot => { "tag", "tokens" } | COMPOSED, from every
      # registry component with a dictionary.
      def rendered_slots
        buckets = Hash.new { |h, k| h[k] = {} }
        source = DictionaryFidelity.snapshot(ROOT).fetch("components")
        registry_components.each do |component|
          next unless component.style_class

          title = component.component_title
          key = SOURCE_FILE.fetch(title.tr("_", "-"), title.tr("_", "-"))
          universe = component.style_class.resolver.all_classes.grep_v(DictionaryFidelity::HOOK).to_set
          REUSES.fetch(title, []).each do |reused|
            universe += "Poetry::Ui::#{reused.camelize}::Style".constantize.resolver.all_classes.grep_v(DictionaryFidelity::HOOK)
          end
          elements = component.style_class.resolver.instance_variable_get(:@elements)
                              .transform_values { |v| Array(v).flat_map(&:split) }
          part_names = component.part_definitions.map { |part| part["name"] }
          scope = { title: title, parts: part_names, universe: universe, source_slots: source.fetch(key, {}).keys,
                    component: title.tr("_", "-"), elements: elements }
          preview_docs(component).each do |html|
            Nokogiri::HTML5.fragment(html).css("[data-slot]").each do |node|
              collect(buckets[key], node, scope)
            end
          end
        end
        buckets
      end

      # One rendered element into its file's bucket. scope: the component's
      # title, declared part names, dictionary token universe, and the
      # source file's slot names.
      def collect(slots, node, scope)
        slot = node["data-slot"]
        foreign_root = node.key?("data-component") && node["data-component"] != scope[:title]
        owned = Poetry::Core::PartContract.owned?(node, scope[:title], scope[:parts])
        if foreign_root && !owned
          # Another component's root wearing a slot the source names here (a
          # composed Button): present, tokens are its own ledger's. Any other
          # nested component is its own file's business.
          slots[slot] ||= DictionaryFidelity::COMPOSED if scope[:source_slots].include?(slot)
          return
        end
        return unless owned

        entry = slots[slot]
        if entry.nil? || entry == DictionaryFidelity::COMPOSED
          entry = slots[slot] = { "tag" => node.name, "tokens" => Set.new }
        end
        classes = node["class"].to_s.split
        entry["tokens"].merge(classes.select { |t| scope[:universe].include?(t) })
        return unless ENV["DICTIONARY_REPORT"]

        # Report mode: the dictionary elements this slot's classes cover (the
        # element a reconciliation script edits for the slot).
        @slot_elements ||= {}
        matches = scope[:elements].select { |_, tokens| tokens.any? && (tokens - classes).empty? }.keys
        (@slot_elements["#{scope[:component]}/#{slot}"] ||= []).concat(matches.map(&:to_s)).uniq!
      end

      def registry_components
        @registry_components ||= Poetry::Core::Registry.new(source_root: Poetry::Ui.root).components
      end

      def preview_docs(component)
        preview = component.name.sub(/Component\z/, "Preview").constantize
        preview.examples.map do |example|
          render_preview(example, from: preview)
          rendered_content.to_s
        end
      rescue NameError
        []
      end
    end
  end
end
