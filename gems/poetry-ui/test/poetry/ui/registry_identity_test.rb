# frozen_string_literal: true

require "test_helper"
require "nokogiri"

module Poetry
  module Ui
    # The identity drift gate: a registry entry declaring
    # "identity" => false claims the component's rendered DOM carries no
    # poetry-minted id - poetry check silences the stable-identity rules
    # on that claim, so a false claim silences a REAL warning. Rendered
    # truth holds it honest: every declaring component's previews are
    # rendered and scanned for the mint shape (SecureRandom.hex(8) or
    # the sequence rung - 16 hex chars after a dash). A component that
    # renders another family's minted ids in its OWN markup declares
    # IDENTITY = true instead (DatePicker's composed Popover).
    #
    # Preview-composed children are the one sanctioned exception: a
    # preview that passes a minting component as BLOCK CONTENT shows its
    # ids without the component owning them - a host's ERB carries the
    # inner helper call, which check flags on its own line. Those live
    # in ALLOWLIST with reasons, and go stale loudly.
    class RegistryIdentityTest < ViewComponent::TestCase
      MINTED_ID = /-\h{16}(\z|-)/
      ALLOWLIST = {
        "poetry/ui/breadcrumb" => "dropdown_crumb: DropdownMenu as caller block content",
        "poetry/ui/button_group" => "popup_triggers: Select/DropdownMenu children in the block"
      }.freeze

      def test_identity_false_components_render_no_minted_ids
        findings = Hash.new { |hash, key| hash[key] = [] }
        identity_free_components.each do |path, klass|
          preview_docs(klass).each do |example, html|
            Nokogiri::HTML5.fragment(html).css("[id]").each do |node|
              findings[path] << "#{example}: #{node["id"]}" if node["id"].match?(MINTED_ID)
            end
          end
        end

        offenders = findings.keys - ALLOWLIST.keys
        stale = ALLOWLIST.keys - findings.keys

        assert_empty offenders,
                     "identity: false but previews render minted ids - the declaration silences " \
                     "a real stable-identity warning (fix the component, or declare " \
                     "IDENTITY = true for composition):\n" +
                     offenders.map { |path| "#{path}: #{findings[path].first(3).join(" | ")}" }.join("\n")
        assert_empty stale, "stale ALLOWLIST entries (no minted ids rendered any more): #{stale.join(", ")}"
      end

      private

      def identity_free_components
        registry = YAML.load_file(Poetry::Ui.root.join(Poetry::Core::Registry::RELATIVE_PATH), aliases: true)
        registry["components"].filter_map do |path, entry|
          [path, entry["class_name"].constantize] if entry["identity"] == false
        end
      end

      def preview_docs(component)
        preview = component.name.sub(/Component\z/, "Preview").constantize
        preview.examples.map do |example|
          render_preview(example, from: preview)
          [example, rendered_content]
        end
      rescue NameError
        []
      end
    end
  end
end
