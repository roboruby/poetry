# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The StableId guards. Two invariants over the whole library:
    #
    # 1. Every rendered preview document carries unique [id] values - the
    #    composed-DOM half of the contract (IDREF wiring resolves to
    #    exactly one target). Registry-driven like the part-contract
    #    tier: new components join automatically.
    # 2. Direct SecureRandom id minting is GONE from component sources -
    #    the only entropy left is the designated ladder fallback
    #    (poetry-core Component#poetry_instance_id) and tag_group's
    #    per-row fallback. Anything else re-opens the random-id disease
    #    one site at a time.
    class IdIntegrityTest < ViewComponent::TestCase
      def test_every_preview_document_has_unique_ids
        components = Poetry::Core::Registry.new(source_root: Poetry::Ui.root).components
        offenders = []
        docs = 0

        components.each do |component|
          preview = component.name.sub(/Component\z/, "Preview").safe_constantize
          next unless preview

          preview.examples.each do |example|
            render_preview(example, from: preview)
            docs += 1
            ids = Nokogiri::HTML.fragment(rendered_content).css("[id]").map { |el| el["id"] }
            dups = ids.tally.select { |_, count| count > 1 }.keys
            offenders << "#{component.component_title}/#{example}: #{dups.join(", ")}" if dups.any?
          rescue StandardError
            nil # previews needing params/context are the preview gate's problem
          end
        end

        assert_operator docs, :>, 300, "tripwire: the preview walk collapsed (#{docs} docs)"
        assert_empty offenders, "duplicate DOM ids in rendered previews:\n  #{offenders.join("\n  ")}"
      end

      def test_no_direct_secure_random_ids_outside_the_designated_fallbacks
        sources = Dir.glob(Poetry::Ui.root.join("app/components/**/*.rb"))
        allowed = [Poetry::Ui.root.join("app/components/poetry/ui/tag_group/component.rb").to_s]
        offenders = sources.select do |path|
          File.read(path).include?("SecureRandom") && !allowed.include?(path)
        end

        assert_operator sources.size, :>, 80, "tripwire: the source glob collapsed"
        assert_empty offenders.map { |p| p.sub(Poetry::Ui.root.to_s, "") },
                     "direct SecureRandom ids outside the ladder - route through poetry_instance_id"
      end
    end
  end
end
