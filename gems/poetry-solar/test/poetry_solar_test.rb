# frozen_string_literal: true

require_relative "test_helper"

class PoetrySolarTest < Minitest::Test
  README = File.read(File.expand_path("../README.md", __dir__))
  SAMPLES = { solar: "home", solar_bold: "home", solar_bold_duotone: "home", solar_broken: "home",
              solar_line_duotone: "home", solar_outline: "home" }.freeze

  def test_registers_every_style_under_its_key
    Poetry::Solar.sets.each do |key, set|
      assert_same set, Poetry::Core::Icons.set(key)
    end
    assert_equal Poetry::Solar::VARIANTS.keys, Poetry::Solar.sets.keys
  end

  # Render an icon offline - vendored files, no network.
  def test_each_style_serves_inner_markup_offline
    SAMPLES.each do |key, name|
      markup = Poetry::Solar.set(key).fetch(name)

      assert_match(/\A<(path|g|circle|rect|polygon|line|polyline|ellipse)\b/, markup, key)
      refute_includes markup, "<svg", "sets store INNER markup; the component owns the wrapper"
    end
  end

  def test_the_readme_counts_match_the_packed_files
    Poetry::Solar.sets.each do |key, set|
      count = set.names.size.to_s.reverse.scan(/\d{1,3}/).join(",").reverse

      assert_includes README, "| `:#{key}` |", key
      assert_match(/\| `:#{key}` \|[^|]*\| #{count} \|/, README, "README count for #{key}")
    end
  end

  def test_the_set_is_vendored_at_the_pinned_commit
    assert_equal PoetrySolar::Fetcher::PINNED_COMMIT, Poetry::Solar.vendored_commit
  end

  def test_each_style_draws_with_its_own_attributes
    Poetry::Solar::VARIANTS.each do |key, (_file, attributes)|
      assert_equal attributes, Poetry::Solar.set(key).svg_attributes
    end
  end

  def test_icon_names_are_traversal_safe
    assert_raises(Poetry::Core::IconNotFound) { Poetry::Solar.set.fetch("../secrets") }
    refute_includes Poetry::Solar.set, "../secrets"
  end

  def test_every_vendored_icon_is_clean
    # The packed files are trusted at render time - scan every line.
    Poetry::Solar.sets.each_value do |set|
      offenders = File.foreach(set.path).grep(/<script|<title|foreignObject|\son[a-z]+=|href="(?!#)[a-z]+:/i)

      assert_empty offenders.map { it[0, 60] }, set.path.basename.to_s
    end
  end

  def test_upstream_names_become_kebab_case_icon_names
    fetcher = PoetrySolar::Fetcher.new

    assert_equal "c-plus-plus", fetcher.icon_name("c++")
    assert_equal "comment-add-03", fetcher.icon_name("comment add-03")
    assert_equal "rubiks-cube", fetcher.icon_name("rubik's-cube")
    assert_equal "backstage-casting", fetcher.icon_name("backstage_casting")
  end

  # CC BY 4.0: every copy credits 480 Design, the source, the license
  # and the changes; the Icon component renders this inside each svg.
  def test_every_style_carries_the_cc_by_attribution
    Poetry::Solar.sets.each_value do |set|
      assert_equal Poetry::Solar::ATTRIBUTION, set.attribution
    end
    ["480 Design", "CC BY 4.0", "creativecommons.org/licenses/by/4.0", "modified"].each do |part|
      assert_includes Poetry::Solar::ATTRIBUTION, part
    end
    assert_includes Poetry::Solar.credit, "480 Design"
  end

  def test_the_license_text_and_notice_ship_in_the_gem
    spec = Gem::Specification.load(File.expand_path("../poetry-solar.gemspec", __dir__))

    assert_equal %w[MIT CC-BY-4.0], spec.licenses
    assert_includes File.read(File.expand_path("../LICENSE-SOLAR.txt", __dir__)),
                    "Attribution 4.0 International"
    assert_includes File.read(File.expand_path("../NOTICE", __dir__)), "480 Design"
  end
end
