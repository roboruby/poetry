# frozen_string_literal: true

require "test_helper"

module Poetry
  module Agent
    module AGUI
      class JsonPatchTest < Minitest::Test
        def test_add_replace_remove_move_copy_and_test
          document = { "a" => { "b" => 1 }, "list" => [1, 2] }
          patched = JsonPatch.apply(document, [
                                      { "op" => "add", "path" => "/a/c", "value" => 3 },
                                      { "op" => "replace", "path" => "/a/b", "value" => 2 },
                                      { "op" => "add", "path" => "/list/-", "value" => 3 },
                                      { "op" => "add", "path" => "/list/0", "value" => 0 },
                                      { "op" => "move", "from" => "/a/c", "path" => "/moved" },
                                      { "op" => "copy", "from" => "/moved", "path" => "/copied" },
                                      { "op" => "test", "path" => "/copied", "value" => 3 },
                                      { "op" => "remove", "path" => "/list/1" }
                                    ])

          assert_equal({ "a" => { "b" => 2 }, "list" => [0, 2, 3], "moved" => 3, "copied" => 3 }, patched)
          assert_equal({ "a" => { "b" => 1 }, "list" => [1, 2] }, document, "the source document is never mutated")
        end

        def test_pointer_escapes_and_whole_document_replace
          patched = JsonPatch.apply({ "a/b" => 1, "m~n" => 2 },
                                    [{ "op" => "replace", "path" => "/a~1b", "value" => 9 }])

          assert_equal 9, patched["a/b"]
          assert_equal({ "x" => 1 },
                       JsonPatch.apply({ "old" => true },
                                       [{ "op" => "replace", "path" => "", "value" => { "x" => 1 } }]))
        end

        def test_failures_are_atomic_and_named
          document = { "a" => 1 }
          error = assert_raises(JsonPatch::Error) do
            JsonPatch.apply(document, [{ "op" => "replace", "path" => "/a", "value" => 2 },
                                       { "op" => "remove", "path" => "/missing" }])
          end

          assert_match(%r{no such path /missing}, error.message)
          assert_equal({ "a" => 1 }, document)
          assert_raises(JsonPatch::Error) { JsonPatch.apply({}, [{ "op" => "test", "path" => "/a", "value" => 1 }]) }
          assert_raises(JsonPatch::Error) { JsonPatch.apply({}, [{ "op" => "explode", "path" => "/a" }]) }
        end
      end
    end
  end
end
