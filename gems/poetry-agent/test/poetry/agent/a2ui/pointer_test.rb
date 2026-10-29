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

  def test_absolute_takes_dot_empty_and_a_trailing_slash
    assert_equal "/bar/foo", Pointer.absolute("foo", "/bar/")
    assert_equal "/user", Pointer.absolute(".", "/user")
    assert_equal "/user", Pointer.absolute("", "/user/")
    assert_equal "/", Pointer.absolute(".", "/")
  end

  def test_a_missing_step_becomes_a_list_before_an_index
    document = {}
    Pointer.upsert(document, "/a/1/b", "x")

    assert_equal({ "a" => [nil, { "b" => "x" }] }, document)
    assert_nil Pointer.get({ "items" => %w[a b] }, "/items/01"), "an index has no leading zero"
  end

  def test_writes_the_spec_refuses
    document = { "user" => { "name" => "Ada" }, "items" => [1] }

    error = assert_raises(Pointer::Error) { Pointer.upsert(document, "/user/name/first", "x") }
    assert_match(/Cannot set path .*: segment 'name' is a primitive value/, error.message)
    assert_raises(Pointer::Error) { Pointer.upsert(document, "/items/0/x", "y") }
    assert_match(/non-numeric segment '01'/, assert_raises(Pointer::Error) do
      Pointer.upsert(document, "/items/01", 2)
    end.message)
    assert_match(/Forbidden path segment '__proto__'/,
                 assert_raises(Pointer::Error) { Pointer.upsert(document, "/__proto__/x", 1) }.message)
    assert_raises(Pointer::Error) { Pointer.upsert(document, "/fresh/10001", 1) }
    assert_raises(Pointer::Error) { Pointer.upsert(document, "/fresh/deep/10001", 1) }
    assert_equal({ "user" => { "name" => "Ada" }, "items" => [1] }, document, "a refused write changes nothing")
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

    assert_equal [9, nil, 3], document["list"], "a removed element leaves its slot, so later indices hold"
  end

  def test_an_array_takes_an_index_up_to_the_cap
    document = { "items" => %w[a b c] }
    Pointer.upsert(document, "/items/10000", "max")

    assert_equal 10_001, document["items"].size
    assert_raises(Pointer::Error) { Pointer.upsert(document, "/items/10001", "x") }
    assert_raises(Pointer::Error) { Pointer.upsert(document, "/items/999999999", "x") }
    assert_raises(Pointer::Error) { Pointer.upsert(document, "/items/10001/name", "x") }
    assert_equal 10_001, document["items"].size, "a refused write allocates nothing"
  end

  def test_an_array_token_that_is_not_an_index_is_refused
    document = { "list" => [1, 2] }

    assert_raises(Pointer::Error) { Pointer.upsert(document, "/list/-5", 9) }
    assert_raises(Pointer::Error) { Pointer.upsert(document, "/list/name", 9) }
    Pointer.upsert(document, "/list/name", nil)

    assert_equal [1, 2], document["list"], "removing what no index names removes nothing"
  end
end
