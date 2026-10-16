# frozen_string_literal: true

require_relative "test_helper"

class PoetryTablerTest < Minitest::Test
  README = File.read(File.expand_path("../README.md", __dir__))
  SAMPLES = { tabler: "home", tabler_filled: "home" }.freeze

  def test_registers_every_style_under_its_key
    Poetry::Tabler.sets.each do |key, set|
      assert_same set, Poetry::Core::Icons.set(key)
    end
    assert_equal Poetry::Tabler::VARIANTS.keys, Poetry::Tabler.sets.keys
  end

  # Render an icon offline - vendored files, no network.
  def test_each_style_serves_inner_markup_offline
    SAMPLES.each do |key, name|
      markup = Poetry::Tabler.set(key).fetch(name)

      assert_match(/\A<(path|g|circle|rect|polygon|line|polyline|ellipse)\b/, markup, key)
      refute_includes markup, "<svg", "sets store INNER markup; the component owns the wrapper"
    end
  end

  def test_the_readme_counts_match_the_packed_files
    Poetry::Tabler.sets.each do |key, set|
      count = set.names.size.to_s.reverse.scan(/\d{1,3}/).join(",").reverse

      assert_includes README, "| `:#{key}` |", key
      assert_match(/\| `:#{key}` \|[^|]*\| #{count} \|/, README, "README count for #{key}")
    end
  end

  def test_the_set_is_vendored_at_the_pinned_commit
    assert_equal PoetryTabler::Fetcher::PINNED_COMMIT, Poetry::Tabler.vendored_commit
  end

  def test_each_style_draws_with_its_own_attributes
    Poetry::Tabler::VARIANTS.each do |key, (_file, attributes)|
      assert_equal attributes, Poetry::Tabler.set(key).svg_attributes
    end
  end

  def test_icon_names_are_traversal_safe
    assert_raises(Poetry::Core::IconNotFound) { Poetry::Tabler.set.fetch("../secrets") }
    refute_includes Poetry::Tabler.set, "../secrets"
  end

  def test_every_vendored_icon_is_clean
    # The packed files are trusted at render time - scan every line.
    Poetry::Tabler.sets.each_value do |set|
      offenders = File.foreach(set.path).grep(/<script|<title|foreignObject|\son[a-z]+=|href="(?!#)[a-z]+:/i)

      assert_empty offenders.map { it[0, 60] }, set.path.basename.to_s
    end
  end

  def test_upstream_names_become_kebab_case_icon_names
    fetcher = PoetryTabler::Fetcher.new

    assert_equal "c-plus-plus", fetcher.icon_name("c++")
    assert_equal "comment-add-03", fetcher.icon_name("comment add-03")
    assert_equal "rubiks-cube", fetcher.icon_name("rubik's-cube")
    assert_equal "backstage-casting", fetcher.icon_name("backstage_casting")
  end
end
