# frozen_string_literal: true

require_relative "test_helper"

class PoetryLucideTest < Minitest::Test
  def test_registers_the_lucide_set
    set = Poetry::Core::Icons.set(:lucide)

    assert_same Poetry::Lucide.set, set
  end

  # Render an icon offline - vendored files, no network.
  def test_fetches_vendored_inner_markup_offline
    markup = Poetry::Lucide.set.fetch(:trash)

    assert_includes markup, "<path"
    refute_includes markup, "<svg", "sets store INNER markup; the component owns the wrapper"
  end

  def test_the_full_set_is_vendored_at_the_pinned_commit
    assert_operator Poetry::Lucide.set.names.size, :>, 1500
    assert_match(/\A[0-9a-f]{40}\z/, Poetry::Lucide.vendored_commit)
  end

  def test_icon_names_are_traversal_safe
    assert_raises(ArgumentError) { Poetry::Lucide.set.fetch("../secrets") }
    refute_includes Poetry::Lucide.set, "../secrets"
  end

  # The fetch pipeline sanitizes a seeded malicious SVG.
  def test_sanitizer_strips_the_seeded_malicious_svg
    malicious = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" onload="alert(1)">
        <script>alert("owned")</script>
        <foreignObject><body xmlns="http://www.w3.org/1999/xhtml">html</body></foreignObject>
        <use href="https://evil.example/sprite.svg#x"/>
        <use href="#local-ok"/>
        <image xlink:href="https://evil.example/x.png" xmlns:xlink="http://www.w3.org/1999/xlink"/>
        <path d="M0 0h24v24" onclick="alert(2)"/>
      </svg>
    SVG

    clean = PoetryLucide::Fetcher.new.sanitize(malicious)

    refute_includes clean, "<script"
    refute_includes clean, "foreignObject"
    refute_includes clean, "evil.example"
    refute_includes clean, "onclick"
    refute_includes clean, "onload"
    assert_includes clean, '<use href="#local-ok"/>', "same-document references survive"
    assert_includes clean, 'd="M0 0h24v24"', "the legitimate path survives"
  end

  def test_every_vendored_icon_is_clean
    # The pipeline's output is trusted at render time - verify the whole
    # vendored tree honors that trust.
    offenders = Poetry::Lucide.set.names.select do |name|
      markup = Poetry::Lucide.set.fetch(name)
      markup.match?(/<script|foreignObject|\son[a-z]+=|href="(?!#)[a-z]+:/i)
    end

    assert_empty offenders
  end
end
