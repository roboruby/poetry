# frozen_string_literal: true

require "test_helper"

class PointerTest < Minitest::Test
  Pointer = Poetry::Agent::A2UI::Pointer

  def test_tokens_unescape_and_treat_root_as_empty
    assert_equal ["a", "b/c", "~d", "0"], Pointer.tokens("/a/b~1c/~0d/0")
    assert_empty Pointer.tokens("/")
    assert_empty Pointer.tokens("")
  end

  def test_build_round_trips
    assert_equal "/a/b~1c/~0d", Pointer.build(["a", "b/c", "~d"])
    assert_equal "/", Pointer.build([])
  end

  def test_absolute_resolves_relative_paths_against_the_scope
    assert_equal "/users/1/name", Pointer.absolute("name", "/users/1")
    assert_equal "/company", Pointer.absolute("/company", "/users/1")
    assert_equal "/name", Pointer.absolute("name")
    assert_equal "/name", Pointer.absolute("name", "/")
  end

  def test_get_walks_hashes_and_arrays
    document = { "tracks" => [{ "title" => "Weightless" }] }

    assert_equal "Weightless", Pointer.get(document, "/tracks/0/title")
    assert_nil Pointer.get(document, "/tracks/9/title")
    assert_nil Pointer.get(document, "/tracks/title")
    assert_equal document, Pointer.get(document, "/")
  end

  def test_upsert_creates_replaces_and_removes
    document = {}
    Pointer.upsert(document, "/user/name", "Ada")

    assert_equal({ "user" => { "name" => "Ada" } }, document)

    Pointer.upsert(document, "/user/name", "Bob")

    assert_equal "Bob", document.dig("user", "name")

    Pointer.upsert(document, "/user/name", nil)

    assert_equal({ "user" => {} }, document)
    assert_equal({ "whole" => 1 }, Pointer.upsert(document, "/", { "whole" => 1 }))
  end

  def test_upsert_into_arrays
    document = { "list" => [1, 2] }
    Pointer.upsert(document, "/list/0", 9)
    Pointer.upsert(document, "/list/-", 3)

    assert_equal [9, 2, 3], document["list"]

    Pointer.upsert(document, "/list/1", nil)

    assert_equal [9, 3], document["list"]
  end
end
