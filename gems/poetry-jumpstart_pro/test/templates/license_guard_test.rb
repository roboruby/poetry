# frozen_string_literal: true

require "test_helper"

# The license guard. Jumpstart Pro is commercial, so every template must be a
# fresh Poetry recreation, never a copy: each one composes Poetry, and none
# shares more than MAX_SIMILARITY of its five-token runs with the engine view
# it shadows. The comparison reads the private checkout in place and only
# when JUMPSTART_PRO_PATH points at it.
class LicenseGuardTest < Minitest::Test
  # The share of five-token runs a template may have in common with the
  # original. Shared contracts (route helpers, i18n keys, ivars) account for
  # the overlap a recreation has; a copy lands far above it.
  MAX_SIMILARITY = 0.5

  # Templates that style with token classes instead of components, and why.
  TOKEN_STYLED = {
    "users/_user.html.erb" => "rendered inside Action Text, which strips component data attributes"
  }.freeze

  def test_every_template_composes_poetry
    TemplateTree.each do |category, relative|
      next if TOKEN_STYLED.key?(relative)

      assert TemplateTree.poetry?(TemplateTree.read(category, relative)),
             "#{category}/#{relative} should compose Poetry components"
    end
  end

  def test_no_template_is_a_copy_of_its_original
    skip "set JUMPSTART_PRO_PATH to compare against your Jumpstart Pro checkout" unless JumpstartRepo.path

    TemplateTree.each do |category, relative|
      original = JumpstartRepo.original_for(relative)
      next unless File.exist?(original)

      similarity = similarity(TemplateTree.read(category, relative), File.read(original))

      message = format("%<path>s shares %<share>d%% of its token runs with Jumpstart's view - rewrite it",
                       path: "#{category}/#{relative}", share: (similarity * 100).round)

      assert_operator similarity, :<=, MAX_SIMILARITY, message
    end
  end

  private

  def similarity(left, right)
    a = shingles(left)
    b = shingles(right)
    return 0.0 if a.empty? || b.empty?

    (a & b).size.fdiv((a | b).size)
  end

  def shingles(text)
    text.scan(/[A-Za-z_$][\w$-]*|\d+|[^\s\w]/).each_cons(5).to_set { |run| run.join(" ") }
  end
end
