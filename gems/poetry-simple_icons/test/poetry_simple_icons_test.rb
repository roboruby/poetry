# frozen_string_literal: true

require_relative "test_helper"

class PoetrySimpleIconsTest < Minitest::Test
  README = File.read(File.expand_path("../README.md", __dir__))
  SAMPLES = { simple_icons: "github" }.freeze

  def test_registers_every_style_under_its_key
    Poetry::SimpleIcons.sets.each do |key, set|
      assert_same set, Poetry::Core::Icons.set(key)
    end
    assert_equal Poetry::SimpleIcons::VARIANTS.keys, Poetry::SimpleIcons.sets.keys
  end

  # Render an icon offline - vendored files, no network.
  def test_each_style_serves_inner_markup_offline
    SAMPLES.each do |key, name|
      markup = Poetry::SimpleIcons.set(key).fetch(name)

      assert_match(/\A<(path|g|circle|rect|polygon|line|polyline|ellipse)\b/, markup, key)
      refute_includes markup, "<svg", "sets store INNER markup; the component owns the wrapper"
    end
  end

  def test_the_readme_counts_match_the_packed_files
    Poetry::SimpleIcons.sets.each do |key, set|
      count = set.names.size.to_s.reverse.scan(/\d{1,3}/).join(",").reverse

      assert_includes README, "| `:#{key}` |", key
      assert_match(/\| `:#{key}` \|[^|]*\| #{count} \|/, README, "README count for #{key}")
    end
  end

  def test_the_set_is_vendored_at_the_pinned_commit
    assert_equal PoetrySimpleIcons::Fetcher::PINNED_COMMIT, Poetry::SimpleIcons.vendored_commit
  end

  def test_each_style_draws_with_its_own_attributes
    Poetry::SimpleIcons::VARIANTS.each do |key, (_file, attributes)|
      assert_equal attributes, Poetry::SimpleIcons.set(key).svg_attributes
    end
  end

  def test_icon_names_are_traversal_safe
    assert_raises(Poetry::Core::IconNotFound) { Poetry::SimpleIcons.set.fetch("../secrets") }
    refute_includes Poetry::SimpleIcons.set, "../secrets"
  end

  def test_every_vendored_icon_is_clean
    # The packed files are trusted at render time - scan every line.
    Poetry::SimpleIcons.sets.each_value do |set|
      offenders = File.foreach(set.path).grep(/<script|<title|foreignObject|\son[a-z]+=|href="(?!#)[a-z]+:/i)

      assert_empty offenders.map { it[0, 60] }, set.path.basename.to_s
    end
  end

  def test_upstream_names_become_kebab_case_icon_names
    fetcher = PoetrySimpleIcons::Fetcher.new

    assert_equal "c-plus-plus", fetcher.icon_name("c++")
    assert_equal "comment-add-03", fetcher.icon_name("comment add-03")
    assert_equal "rubiks-cube", fetcher.icon_name("rubik's-cube")
    assert_equal "backstage-casting", fetcher.icon_name("backstage_casting")
  end

  def test_every_logo_has_its_brand_name_and_colour
    assert_equal({ title: "GitHub", hex: "181717" }, Poetry::SimpleIcons.brand(:github))
    assert_nil Poetry::SimpleIcons.brand(:"no-such-brand")
    missing = Poetry::SimpleIcons.set.names.reject { |name| Poetry::SimpleIcons.brand(name) }

    assert_empty missing
  end
end
