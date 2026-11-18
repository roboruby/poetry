# frozen_string_literal: true

require "test_helper"
require "json"
require "poetry/agent/a2ui/schema"

module Poetry
  module Agent
    module A2UI
      # The strict tier's JSON Schema 2020-12 interpreter, keyword by keyword:
      # what each supported keyword accepts and refuses, what it reports, and
      # what the interpreter refuses to compile.
      class SchemaTest < Minitest::Test
        BASE = "https://example.test/schema.json"

        def schema(doc, root: BASE, **others)
          Schema.new(documents: { BASE => doc, **others.transform_keys(&:to_s) }, root: root)
        end

        def assert_verdicts(schema, valid: [], invalid: [])
          valid.each do |instance|
            assert schema.valid?(instance), "expected #{instance.inspect} to validate"
            assert_empty schema.errors(instance), "no problems for #{instance.inspect}"
          end
          invalid.each do |instance|
            refute schema.valid?(instance), "expected #{instance.inspect} to fail"
            refute_empty schema.errors(instance), "a problem for #{instance.inspect}"
          end
        end

        def test_types_follow_json_with_whole_floats_as_integers
          assert_verdicts schema({ "type" => "integer" }), valid: [1, 1.0, -3], invalid: [1.5, "1", true, nil]
          assert_verdicts schema({ "type" => "number" }), valid: [1, 1.5], invalid: ["1", [1]]
          assert_verdicts schema({ "type" => %w[string null] }), valid: ["a", nil], invalid: [1, [], {}]
          assert_verdicts schema({ "type" => "boolean" }), valid: [true, false], invalid: [0, "true"]
          assert_equal ["(root) type: expected integer, received number"],
                       schema({ "type" => "integer" }).errors(1.5).map(&:to_s)
          assert_raises(ArgumentError) { schema({ "type" => "string" }).valid?(:symbol) }
        end

        def test_properties_required_and_additional_properties
          closed = schema({ "type" => "object", "properties" => { "a" => { "type" => "string" } }, "required" => ["a"],
                            "additionalProperties" => false })

          assert_verdicts closed, valid: [{ "a" => "x" }], invalid: [{}, { "a" => 1 }, { "a" => "x", "b" => 1 }]
          assert_equal ["/b additionalProperties: property not allowed"],
                       closed.errors({ "a" => "x", "b" => 1 }).map(&:to_s)
          assert_equal ["/a~1b~0c additionalProperties: property not allowed"],
                       closed.errors({ "a" => "x", "a/b~c" => 1 }).map(&:to_s)
          assert_verdicts schema({ "additionalProperties" => { "type" => "integer" } }),
                          valid: [{ "x" => 1 }, 7], invalid: [{ "x" => "1" }]
          assert_verdicts schema({ "minProperties" => 1, "maxProperties" => 2 }),
                          valid: [{ "a" => 1 }, { "a" => 1, "b" => 2 }], invalid: [{}, { "a" => 1, "b" => 2, "c" => 3 }]
          assert_verdicts schema({ "dependentRequired" => { "a" => ["b"] } }),
                          valid: [{}, { "b" => 1 }, { "a" => 1, "b" => 2 }], invalid: [{ "a" => 1 }]
          assert_verdicts schema({ "dependentSchemas" => { "a" => { "required" => ["c"] } } }),
                          valid: [{ "b" => 1 }, { "a" => 1, "c" => 2 }], invalid: [{ "a" => 1 }]
          assert_verdicts schema({ "propertyNames" => { "not" => { "pattern" => "^@([^@]|$)" } } }),
                          valid: [{ "@@x" => 1, "a" => 2 }], invalid: [{ "@path" => 1 }, { "@" => 1 }]
        end

        def test_unevaluated_properties_see_the_names_every_passing_subschema_evaluated
          doc = { "allOf" => [{ "properties" => { "id" => { "type" => "string" } } }],
                  "oneOf" => [{ "properties" => { "kind" => { "const" => "a" }, "x" => {} }, "required" => ["kind"] },
                              { "properties" => { "kind" => { "const" => "b" }, "y" => {} }, "required" => ["kind"] }],
                  "unevaluatedProperties" => false }
          closed = schema(doc)

          assert_verdicts closed, valid: [{ "id" => "1", "kind" => "a", "x" => 1 }, { "kind" => "b", "y" => 2 }],
                                  invalid: [{ "kind" => "a", "y" => 1 }, { "kind" => "a", "z" => 1 }]
          assert_equal ["/z unevaluatedProperties: property not allowed"],
                       closed.errors({ "kind" => "a", "z" => 1 }).map(&:to_s)
          assert_verdicts schema({ "$ref" => "#/$defs/Base", "unevaluatedProperties" => false,
                                   "$defs" => { "Base" => { "properties" => { "a" => {} } } } }),
                          valid: [{ "a" => 1 }], invalid: [{ "b" => 1 }]
          assert_verdicts schema({ "if" => { "properties" => { "a" => { "const" => 1 } } },
                                   "then" => { "properties" => { "b" => {} } }, "unevaluatedProperties" => false }),
                          valid: [{ "a" => 1, "b" => 2 }], invalid: [{ "a" => 2, "b" => 2 }]
          assert_verdicts schema({ "properties" => { "a" => {} }, "unevaluatedProperties" => { "type" => "integer" } }),
                          valid: [{ "a" => "s", "b" => 1 }], invalid: [{ "b" => "s" }]
          assert_verdicts schema({ "allOf" => [{ "unevaluatedProperties" => true }],
                                   "unevaluatedProperties" => false }), valid: [{ "x" => 1 }]
          wide = (1..20).to_h { |i| ["k#{i}", i] }

          assert_verdicts schema({ "additionalProperties" => true, "unevaluatedProperties" => false }), valid: [wide]
          noisy = schema({ "allOf" => [{ "properties" => { "a" => { "type" => "string" } } }],
                           "unevaluatedProperties" => false })

          assert_equal ["/a type: expected string, received integer"], noisy.errors({ "a" => 1 }).map(&:to_s),
                       "a failure is not repeated as an unevaluated property"
        end

        def test_pattern_properties_take_the_identifier_classes
          identifier = "^[\\p{XID_Start}_][\\p{XID_Continue}]*$"
          names = schema({ "patternProperties" => { identifier => { "type" => "string" } },
                           "additionalProperties" => false })

          assert_verdicts names, valid: [{ "name" => "x", "_a1" => "y", "élan" => "z", "名前" => "v" }],
                                 invalid: [{ "1bad" => "x" }, { "name" => 1 }, { "a-b" => "x" }]
        end

        def test_const_and_enum_compare_as_json
          assert_verdicts schema({ "const" => 1 }), valid: [1, 1.0], invalid: [true, "1"]
          assert_verdicts schema({ "const" => false }), valid: [false], invalid: [0, nil]
          assert_verdicts schema({ "const" => { "a" => 1, "b" => [1, 2] } }),
                          valid: [{ "b" => [1, 2.0], "a" => 1 }], invalid: [{ "a" => 1 }, { "a" => 1, "b" => [2, 1] }]
          assert_verdicts schema({ "enum" => ["a", nil, 2] }), valid: ["a", nil, 2.0], invalid: ["b", false]
          assert_equal ["(root) enum: expected one of \"a\", nil, 2"],
                       schema({ "enum" => ["a", nil, 2] }).errors("b").map(&:to_s)
        end

        def test_one_of_any_of_all_of_and_not
          one = schema({ "oneOf" => [{ "type" => "integer" }, { "minimum" => 2 }] })

          assert_verdicts one, valid: [1, "x"], invalid: [3, 1.5]
          assert_equal ["(root) oneOf: matches more than one oneOf schema"], one.errors(3).map(&:to_s)
          assert_verdicts schema({ "anyOf" => [{ "type" => "string" }, { "type" => "null" }] }),
                          valid: ["a", nil], invalid: [1]
          assert_verdicts schema({ "allOf" => [{ "minimum" => 1 }, { "maximum" => 3 }] }), valid: [2], invalid: [0, 4]
          assert_verdicts schema({ "not" => { "type" => "string" } }), valid: [1], invalid: ["a"]
          assert_equal ["(root) not: matches a schema it must not match"],
                       schema({ "not" => { "type" => "string" } }).errors("a").map(&:to_s)
          assert_verdicts schema({ "anyOf" => [false] }), invalid: [1]
          assert_equal ["(root) false: no value is allowed here"], schema(false).errors(1).map(&:to_s)
        end

        def test_a_failed_union_is_explained_by_the_branch_the_instance_meant
          action = schema({ "oneOf" => [{ "properties" => { "event" => { "type" => "object" } },
                                          "required" => ["event"] },
                                        { "properties" => { "functionCall" => { "type" => "object" } },
                                          "required" => ["functionCall"] }] })

          assert_equal ["(root) oneOf: matches none of the oneOf schemas",
                        "/functionCall type: expected object, received integer"],
                       action.errors({ "functionCall" => 1 }).map(&:to_s)
          any = schema({ "anyOf" => [{ "type" => "string" }, { "type" => "integer", "minimum" => 5 }] })

          assert_equal ["(root) anyOf: matches none of the anyOf schemas", "(root) minimum: 1 violates minimum 5"],
                       any.errors(1).map(&:to_s)
        end

        def test_if_then_else
          assert_verdicts schema({ "if" => { "type" => "string" }, "then" => { "minLength" => 2 },
                                   "else" => { "minimum" => 0 } }),
                          valid: ["ab", 1], invalid: ["a", -1]
          assert_verdicts schema({ "then" => { "type" => "string" }, "else" => false }), valid: [1, "a"]
          assert_verdicts schema({ "if" => { "type" => "string" }, "else" => { "type" => "null" } }),
                          valid: ["a", nil], invalid: [1]
        end

        def test_refs_resolve_across_documents_fragments_pointers_and_anchors
          docs = {
            "https://example.test/keyed.json" => {
              "$id" => "https://example.test/main.json",
              "$defs" => { "Name" => { "$ref" => "common.json#/$defs/Text" }, "a/b" => { "const" => "slash" } },
              "components" => { "Text" => { "$ref" => "#/$defs/Name" } },
              "properties" => { "name" => { "$ref" => "#/components/Text" }, "tag" => { "$ref" => "common.json#tag" },
                                "abs" => { "$ref" => "https://example.test/common.json#/$defs/Text" },
                                "slash" => { "$ref" => "#/$defs/a~1b" }, "pct" => { "$ref" => "#/$defs/a%7E1b" } }
            },
            "https://example.test/common.json" => {
              "$defs" => { "Text" => { "type" => "string" }, "Tag" => { "$anchor" => "tag", "enum" => %w[a b] } }
            }
          }
          main = Schema.new(documents: docs, root: "https://example.test/main.json")
          valid = { "name" => "x", "tag" => "a", "abs" => "y", "slash" => "slash", "pct" => "slash" }

          assert_verdicts main, valid: [valid],
                                invalid: [{ "name" => 1 }, { "tag" => "c" }, { "abs" => 2 }, { "slash" => 1 }]
          assert Schema.new(documents: docs, root: "https://example.test/keyed.json").valid?(valid),
                 "the key still finds a document its $id renamed"
          assert_verdicts Schema.new(documents: docs, root: "https://example.test/common.json#/$defs/Tag"),
                          valid: ["a"], invalid: ["c"]
          tree = schema({ "properties" => { "children" => { "items" => { "$ref" => "#" } } }, "required" => ["v"] })

          assert_verdicts tree, valid: [{ "v" => 1, "children" => [{ "v" => 2, "children" => [] }] }],
                                invalid: [{ "v" => 1, "children" => [{ "children" => [] }] }]
          assert_equal "/children/0 required: missing required 'v'",
                       tree.errors({ "v" => 1, "children" => [{}] }).first.to_s
        end

        def test_dynamic_ref_resolves_against_the_outermost_dynamic_anchor
          tree_uri = "https://example.test/tree"
          strict_uri = "https://example.test/strict-tree"
          docs = {
            tree_uri => { "$id" => tree_uri, "$dynamicAnchor" => "node", "type" => "object",
                          "properties" => { "data" => true,
                                            "children" => { "type" => "array",
                                                            "items" => { "$dynamicRef" => "#node" } } } },
            strict_uri => { "$id" => strict_uri, "$dynamicAnchor" => "node", "$ref" => "tree",
                            "unevaluatedProperties" => false }
          }
          loose = Schema.new(documents: docs, root: tree_uri)
          strict = Schema.new(documents: docs, root: strict_uri)
          typo = { "children" => [{ "daat" => 1 }] }

          assert loose.valid?(typo)
          refute strict.valid?(typo), "the strict tree's anchor governs the nested nodes"
          assert strict.valid?({ "children" => [{ "data" => 1, "children" => [] }] })
          assert_equal ["/children/0/daat unevaluatedProperties: property not allowed"], strict.errors(typo).map(&:to_s)
          static = schema({ "$defs" => { "N" => { "type" => "integer" } },
                            "items" => { "$dynamicRef" => "#/$defs/N" } })

          assert_verdicts static, valid: [[1]], invalid: [["a"]]
          plain = schema({ "$defs" => { "A" => { "$anchor" => "foo", "type" => "integer" } },
                           "items" => { "$dynamicRef" => "#foo" } })

          assert_verdicts plain, valid: [[1]], invalid: [["a"]]
          elsewhere = Schema.new(documents: { BASE => { "$dynamicRef" => "other.json#node" },
                                              "https://example.test/other.json" => { "$dynamicAnchor" => "node",
                                                                                     "type" => "integer" } },
                                 root: BASE)

          assert_verdicts elsewhere, valid: [1], invalid: ["a"]
        end

        def test_the_meta_schema_runs_through_dynamic_refs
          require "json_schemer"
          drafts = JSONSchemer::Draft202012::Meta::SCHEMAS.to_h { |uri, schema| [uri.to_s, schema] }
          drafts[JSONSchemer::Draft202012::BASE_URI.to_s] = JSONSchemer::Draft202012::SCHEMA
          meta = Schema.new(documents: drafts, root: Schema::DIALECT)

          assert_verdicts meta, valid: [{ "properties" => { "a" => { "type" => "string", "pattern" => "^a" } } }, true],
                                invalid: [{ "type" => 1 }, { "properties" => { "a" => { "minLength" => -1 } } },
                                          { "items" => { "pattern" => "(" } }]
        end

        def test_arrays
          tuple = schema({ "prefixItems" => [{ "type" => "string" }], "items" => { "type" => "integer" },
                           "minItems" => 1, "maxItems" => 3 })

          assert_verdicts tuple, valid: [["a"], ["a", 1, 2]], invalid: [[], [1], %w[a b], ["a", 1, 2, 3]]
          assert_equal ["/1 type: expected integer, received string"], tuple.errors(%w[a b]).map(&:to_s)
          assert_verdicts schema({ "contains" => { "const" => 1 } }), valid: [[0, 1]], invalid: [[], [0]]
          assert_verdicts schema({ "contains" => { "const" => 1 }, "minContains" => 2, "maxContains" => 3 }),
                          valid: [[1, 1], [1, 2, 1, 1]], invalid: [[1], [1, 1, 1, 1]]
          assert_verdicts schema({ "contains" => { "const" => 1 }, "minContains" => 0 }), valid: [[], [2]]
          assert_verdicts schema({ "uniqueItems" => true }),
                          valid: [[1, 2], [{ "a" => 1 }, { "a" => 2 }]],
                          invalid: [[1, 1.0], [{ "a" => 1, "b" => 2 }, { "b" => 2, "a" => 1 }]]
        end

        def test_string_and_number_bounds
          assert_verdicts schema({ "minLength" => 2, "maxLength" => 3 }), valid: %w[ab 名前x 😀😀], invalid: %w[a abcd]
          assert_verdicts schema({ "minimum" => 1, "exclusiveMaximum" => 3, "multipleOf" => 0.5 }),
                          valid: [1, 2.5], invalid: [0.5, 3, 1.25]
          assert_verdicts schema({ "exclusiveMinimum" => 0, "maximum" => 1 }), valid: [1, 0.1], invalid: [0, 1.1]
          assert_equal ["(root) minLength: shorter than 2"], schema({ "minLength" => 2 }).errors("a").map(&:to_s)
        end

        def test_patterns_mean_what_ecma_262_says
          assert_verdicts schema({ "pattern" => "^a.c$" }), valid: ["abc"],
                                                            invalid: ["xabc", "abc\n", "a\nc", "a\rc", "a c"]
          assert_verdicts schema({ "pattern" => "a\\sb" }), valid: ["a b", "a b", "a　b"], invalid: ["ab"]
          assert_verdicts schema({ "pattern" => "a\\b" }), valid: ["a b", "aé"], invalid: ["ab"]
          assert_verdicts schema({ "pattern" => "a\\Sb" }), valid: ["axb"], invalid: ["a b", "a\u00a0b"]
          assert_verdicts schema({ "pattern" => "^a\\B" }), valid: ["ab"], invalid: ["a", "a b", "aé"]
          assert_verdicts schema({ "pattern" => "^a+?$" }), valid: ["aa"], invalid: ["b"]
          assert_verdicts schema({ "pattern" => "^a{b$" }), valid: ["a{b"], invalid: ["ab"]
          assert_verdicts schema({ "pattern" => "x[]" }), invalid: ["x", "x]"]
          assert_verdicts schema({ "pattern" => "^[^]$" }), valid: ["\n"], invalid: [""]
          assert_verdicts schema({ "pattern" => "^#[0-9a-fA-F]{6}$" }), valid: ["#a0B1c2"], invalid: ["#ff00f"]
          assert_verdicts schema({ "pattern" => "^(?<word>a+)\\k<word>$" }), valid: ["aa"], invalid: ["aaa"]
          assert_equal ["(root) pattern: does not match ^a+$"], schema({ "pattern" => "^a+$" }).errors("b").map(&:to_s)
        end

        def test_a_pattern_that_runs_out_of_time_fails
          slow = "^(a|a)*\\1$"
          hostile = "#{"a" * 40}!"

          refute schema({ "pattern" => slow }).valid?(hostile)
          assert_equal ["(root) pattern: timed out matching #{slow}"],
                       schema({ "pattern" => slow }).errors(hostile).map(&:to_s)
          refute schema({ "patternProperties" => { slow => {} } }).valid?({ hostile => 1 })
          problem = schema({ "patternProperties" => { slow => {} } }).errors({ hostile => 1 }).first

          assert_equal ["/#{hostile}", "patternProperties"], [problem.pointer, problem.keyword]
        end

        def test_formats_are_asserted
          {
            "uri" => [["https://a2ui.org/x?q=1#f", "urn:isbn:1"], ["not a uri", "/relative", "http://a b"]],
            "uri-reference" => [["/relative", "#frag", "?a=b"], ["http://[bad", "a b", "?a b", "mailto:a?b c"]],
            "date-time" => [["2026-10-29T12:00:00Z", "2026-10-29t12:00:00.5+02:00", "1998-12-31T23:59:60Z"],
                            ["2026-13-01T00:00:00Z", "2026-10-29T12:00:00", "2026-10-29T24:00:00Z",
                             "1998-12-31T12:59:60Z"]],
            "date" => [["2026-02-28"], ["2026-02-30", "2026-2-1"]],
            "time" => [["12:00:00Z", "12:00:00.25-05:00"], ["12:00:00", "25:00:00Z"]],
            "regex" => [["^a+$", "(?<=a)b"], ["(", "\\A"]],
            "email" => [["anything goes"], []]
          }.each do |format, (valid, invalid)|
            assert_verdicts schema({ "format" => format }), valid: valid + [5], invalid: invalid
          end
          assert_equal ["(root) format: not a valid date"], schema({ "format" => "date" }).errors("x").map(&:to_s)
        end

        FUNCTIONS = %w[formatString formatNumber formatCurrency formatDate pluralize required regex length numeric email
                       openUrl and or not].freeze

        # A miniature of A2UI's dynamic values: a string, a binding or a call,
        # the calls a const-discriminated union whose arguments nest more values.
        def calls
          @calls ||= schema({
                              "$defs" => {
                                "Dynamic" => { "oneOf" => [{ "type" => "string" }, { "$ref" => "#/$defs/Binding" },
                                                           { "$ref" => "#/$defs/Call" }] },
                                "Binding" => { "type" => "object", "required" => ["@path"],
                                               "properties" => { "@path" => { "type" => "string" } },
                                               "additionalProperties" => false },
                                "Call" => { "type" => "object",
                                            "allOf" => [{ "properties" => { "@call" => { "type" => "string" } },
                                                          "required" => ["@call"] },
                                                        { "$ref" => "#/$defs/anyFunction" }],
                                            "unevaluatedProperties" => false },
                                "anyFunction" => { "oneOf" => FUNCTIONS.map do |name|
                                  { "$ref" => "#/functions/#{name}" }
                                end }
                              },
                              "functions" => FUNCTIONS.to_h do |name|
                                [name, { "type" => "object", "required" => %w[@call args],
                                         "properties" => {
                                           "@call" => { "const" => name },
                                           "args" => { "type" => "object", "required" => ["value"],
                                                       "properties" => { "value" => { "$ref" => "#/$defs/Dynamic" } },
                                                       "additionalProperties" => false }
                                         } }]
                              end
                            }, root: "#{BASE}#/$defs/Dynamic")
        end

        def nest(depth, leaf, name = "formatString")
          depth.times.reduce(leaf) { |value, _| { "@call" => name, "args" => { "value" => value } } }
        end

        def test_the_discriminator_takes_nested_calls_straight_to_their_function
          assert calls.valid?(nest(12, "x"))
          assert calls.valid?(nest(6, { "@path" => "/a" }, "pluralize"))
          problems = calls.errors(nest(12, 1))
          leaf = "/args/value" * 12

          assert_equal ["#{leaf} oneOf: matches none of the oneOf schemas",
                        "#{leaf} type: expected string|object, received integer"], problems.last(2).map(&:to_s)
          assert_operator problems.size, :<, 60, "the explanation stays linear in the nesting"
          unknown = calls.errors(nest(3, nest(1, "x", "nope"))).map(&:to_s)

          assert_includes unknown, "#{"/args/value" * 3} oneOf: '@call' \"nope\" names no oneOf schema"
          assert_includes calls.errors({ "@call" => 5, "args" => {} }).map(&:to_s),
                          "(root) oneOf: '@call' 5 names no oneOf schema"
        end

        def test_a_discriminator_is_found_through_refs_and_all_of
          kind_a = { "properties" => { "kind" => { "const" => "a" } }, "required" => ["kind"] }
          with_n = { "properties" => { "kind" => { "const" => "a" }, "n" => { "type" => "integer" } } }
          doc = { "$defs" => { "A" => with_n },
                  "oneOf" => [{ "allOf" => [{ "$ref" => "#/$defs/A" }, kind_a] },
                              { "properties" => { "kind" => { "const" => "b" } }, "required" => ["kind"] }] }
          union = schema(doc)

          assert_verdicts union, valid: [{ "kind" => "a", "n" => 1 }, { "kind" => "b", "n" => "x" }],
                                 invalid: [{ "kind" => "a", "n" => "x" }, { "kind" => "c" }, {}]
          assert_equal ["(root) oneOf: 'kind' \"c\" names no oneOf schema"], union.errors({ "kind" => "c" }).map(&:to_s)
          assert_equal ["(root) oneOf: 'kind' is missing"], union.errors({}).map(&:to_s)
        end

        def test_without_a_provable_discriminator_every_branch_is_evaluated
          clash = schema({ "oneOf" => [{ "properties" => { "k" => { "const" => "a" } }, "required" => ["k"] },
                                       { "properties" => { "k" => { "const" => "a" }, "n" => { "type" => "integer" } },
                                         "required" => ["k"] }] })

          assert_verdicts clash, valid: [{ "k" => "a", "n" => "x" }], invalid: [{ "k" => "a" }, { "k" => "b" }]
          assert_equal "matches more than one oneOf schema", clash.errors({ "k" => "a" }).first.detail
          conditional = schema({ "oneOf" => [{ "anyOf" => [{ "properties" => { "k" => { "const" => "a" } } }],
                                               "required" => ["k"] },
                                             { "properties" => { "k" => { "const" => "b" } }, "required" => ["k"] }] })

          assert_verdicts conditional, valid: [{ "k" => "a" }, { "k" => "b" }], invalid: [{ "k" => [] }]
          assert_equal "matches none of the oneOf schemas", conditional.errors({ "k" => [] }).first.detail
        end

        def test_a_walk_past_the_depth_limit_raises_instead_of_overflowing
          nested = schema({ "items" => { "$ref" => "#" } })
          deep = 200.times.reduce([]) { |value, _| [value] }
          shallow = 50.times.reduce([]) { |value, _| [value] }

          assert nested.valid?(shallow)
          assert_raises(Schema::LimitError) { nested.valid?(deep) }
          assert_match %r{deeper than 128 at '(/0)+'}, assert_raises(Schema::LimitError) { nested.errors(deep) }.message
          assert_raises(Schema::LimitError) { schema({ "$ref" => "#" }).valid?(1) }
          assert_equal 128, Schema::MAX_DEPTH
        end

        def test_a_schema_outside_the_subset_is_refused_at_construction
          [
            [{ "$schema" => "http://json-schema.org/draft-07/schema#" }, /only .*2020-12/],
            [{ "unevaluatedItems" => false }, /unevaluatedItems/],
            [{ "$recursiveRef" => "#" }, /\$recursiveRef/],
            [{ "dependencies" => {} }, /dependencies/],
            [{ "$defs" => { "x" => { "$id" => "https://other.test/" } } }, /embedded \$id/],
            [{ "required" => "a" }, /malformed required/],
            [{ "minLength" => -1 }, /malformed minLength/],
            [{ "type" => "float" }, /unknown type float/],
            [{ "items" => [{}] }, /object or a boolean/],
            [{ "pattern" => "(?<=a)b" }, /lookbehind, which this validator cannot match/],
            [{ "pattern" => "\\p{L}" }, /\\p\{L\}/],
            [{ "pattern" => "[a&&b]" }, /&& inside a class/],
            [{ "pattern" => "[\\w--_]" }, /-- inside a class/],
            [{ "pattern" => "[[a]]" }, /\[ inside a class/],
            [{ "pattern" => "\\cA" }, /\\c/],
            [{ "pattern" => "\\Aa" }, /\\A, which is not ECMA-262/],
            [{ "pattern" => "(?i)a" }, /\(\?i, which is not ECMA-262/],
            [{ "pattern" => "a++" }, /possessive/],
            [{ "pattern" => "a{,3}" }, /\{,3\}/],
            [{ "pattern" => "(" }, /does not compile/],
            [{ "patternProperties" => { "\\h" => {} } }, /\\h/],
            [{ "pattern" => "\\pL" }, /\\p\{\}/],
            [{ "pattern" => "[\\B]" }, /\\B in a class/],
            [{ "pattern" => "a\\" }, /does not compile/],
            [{ "$ref" => "#/$defs/X",
               "$defs" => { "X" => { "$schema" => "https://json-schema.org/draft/2019-09/schema" } } },
             %r{only .*2020-12/schema is supported, not .*2019-09}],
            [{ "$ref" => "#/elsewhere", "elsewhere" => { "$id" => "https://other.test/" } }, /embedded \$id/],
            [{ "properties" => { "a" => { "$ref" => "#/$defs/Bad" } },
               "$defs" => { "Bad" => { "unevaluatedItems" => 1 } } }, /unevaluatedItems/]
          ].each do |doc, message|
            error = assert_raises(Schema::Unsupported, doc.inspect) { schema(doc) }

            assert_match message, error.message
          end
          assert schema({ "$defs" => { "Unreached" => { "unevaluatedItems" => false } } }).valid?(1),
                 "only what the root reaches compiles"
        end

        def test_a_reference_nothing_resolves_is_refused_at_construction
          [{ "$ref" => "missing.json" }, { "$ref" => "#/$defs/nope" }, { "$ref" => "#nope" },
           { "$ref" => "#/items/3", "items" => [] }, { "$ref" => "http://[bad" },
           { "$ref" => "#/$defs/X/type/0", "$defs" => { "X" => { "type" => "string" } } }].each do |doc|
            assert_raises(Schema::UnknownRef, doc.inspect) { schema(doc) }
          end
          assert_raises(Schema::UnknownRef) { schema({}, root: "https://example.test/none.json") }
          assert_raises(Schema::UnknownRef) { schema({}, root: "#{BASE}#/nope") }
        end

        def test_documents_need_absolute_uris_of_their_own
          assert_raises(ArgumentError) { Schema.new(documents: { "relative.json" => {} }, root: "relative.json") }
          assert_raises(ArgumentError) do
            Schema.compile({ "https://a.test/1" => { "$id" => "https://a.test/x" }, "https://a.test/x" => {} })
          end
          assert_raises(ArgumentError) { Schema.compile([]) }
          assert_raises(ArgumentError) { Schema.compile({ "http://[bad" => {} }) }
        end

        def test_problems_come_in_walk_order_with_their_pointer_and_keyword
          doc = { "type" => "object", "required" => ["c"],
                  "properties" => { "a" => { "type" => "string" }, "b" => { "enum" => ["x"] } } }
          problems = schema(doc).errors({ "a" => 1, "b" => "y" })

          assert_equal([["", "required"], ["/a", "type"], ["/b", "enum"]], problems.map { |p| [p.pointer, p.keyword] })
          assert_equal "(root) required: missing required 'c'", problems.first.to_s
          assert_equal Schema::Problem.new(pointer: "/a", keyword: "type", detail: "expected string, received integer"),
                       problems[1]
        end

        def test_a_compiler_shares_roots_and_survives_one_that_fails
          docs = { BASE => { "$defs" => { "Good" => { "type" => "string" },
                                          "Bad" => { "allOf" => [{ "$ref" => "#/$defs/Good" },
                                                                 { "unevaluatedItems" => 1 }] } } } }
          compiler = Schema.compile(docs)
          good = compiler.schema("#{BASE}#/$defs/Good")

          assert_same good, compiler.schema("#{BASE}#/$defs/Good")
          assert_equal "#{BASE}#/$defs/Good", good.root
          assert_raises(Schema::Unsupported) { compiler.schema("#{BASE}#/$defs/Bad") }
          assert good.valid?("x")
          member = compiler.schema("#{BASE}#/$defs/Bad/allOf/0")

          assert_verdicts member, valid: ["y"], invalid: [1]
          assert Schema.new(documents: compiler, root: "#{BASE}#/$defs/Good").valid?("z")
        end
      end

      # The interpreter against a JSON Schema validator (json_schemer, test
      # only), over the vendored A2UI material: every basic-catalog example
      # message of both versions against its version's message schema with
      # the basic catalog plugged in, a seeded set of mutants of them, and the
      # catalog documents against the catalog meta-schema. Verdicts must agree,
      # and `errors` must be empty exactly when `valid?` says so.
      class SchemaCrossCheckTest < Minitest::Test
        UPSTREAM = File.expand_path("../../../fixtures/a2ui/upstream", __dir__)

        VERSIONS = {
          "v0_9" => { dir: "specification/v0_9/json", base: "https://a2ui.org/specification/v0_9/",
                      catalog: "specification/v0_9/catalogs/basic/catalog.json",
                      examples: "specification/v0_9/catalogs/basic/examples", root: "server_to_client.json" },
          "v1_0" => { dir: "specification/v1_0/json", base: "https://a2ui.org/specification/v1_0/",
                      catalog: "catalogs/basic/v1/catalog.json",
                      examples: "catalogs/basic/v1/examples", root: "agent_to_renderer.json" }
        }.freeze

        # The mutation material: values to retype with, keys to add, strings to swap in.
        VALUES = [nil, true, false, 0, -3, 1.5, 2.0, "", "x", [], ["a"], {}, { "@path" => "/a" }, { "path" => "/a" },
                  { "@call" => "formatString", "args" => { "value" => "a" } },
                  { "call" => "required", "args" => { "value" => 1 } }, { "@call" => "@index" },
                  { "@path" => "/a", "extra" => 1 }, { "event" => { "name" => "go" } },
                  { "functionCall" => { "@call" => "openUrl", "args" => { "url" => "https://a.b" } } }].freeze
        KEYS = %w[zz @path @call @x @@x component id catalogId 1bad a2ui_x accessibility checks weight variant child
                  children text action version surfaceId theme metadata extensions type properties required allOf
                  returnType $ref].freeze
        STRINGS = ["", "Text", "Column", "Button", "h1", "caption", "body", "@index", "formatString", "required",
                   "not a uri", "https://x.y/z", "2026-01-01", "12:00:00Z", "2026-01-01T00:00:00Z", "2026-13-01",
                   "#ff00ff", "#ff00f", "1.0", "v0.9", "VALIDATION_FAILED", "object", "string"].freeze

        class << self
          # A version's documents with its basic catalog plugged in where the
          # message schema says `catalog.json`, as the spec's own test runner
          # does: the catalog's `$id` moved there, the `anyComponent` and
          # `anyFunction` unions built when missing, a `#/$defs/X` the catalog
          # does not define pointed at common types, v0.9's theme in `$defs`.
          def documents(version)
            (@documents ||= {})[version] ||= begin
              spec = VERSIONS.fetch(version)
              docs = Dir[File.join(UPSTREAM, spec[:dir], "*.json")].to_h do |file|
                [spec[:base] + File.basename(file), JSON.parse(File.read(file))]
              end
              docs["#{spec[:base]}catalog.json"] = surface_catalog(version, docs)
              docs
            end
          end

          def surface_catalog(version, docs)
            spec = VERSIONS.fetch(version)
            catalog = JSON.parse(File.read(File.join(UPSTREAM, spec[:catalog])))
            catalog["$id"] = "#{spec[:base]}catalog.json"
            defs = (catalog["$defs"] ||= {})
            retarget(catalog, defs.keys, docs.fetch("#{spec[:base]}common_types.json")["$defs"].keys)
            defs["anyComponent"] ||= { "oneOf" => (catalog["components"] || {}).keys.map do |name|
              { "allOf" => [{ "$ref" => "#/components/#{name}" },
                            { "properties" => { "component" => { "const" => name } }, "required" => ["component"] }] }
            end }
            defs["anyFunction"] ||= { "oneOf" => (catalog["functions"] || {}).keys.map do |n|
              { "$ref" => "#/functions/#{n}" }
            end }
            defs["theme"] ||= catalog.delete("theme") || true unless version == "v1_0"
            catalog
          end

          def retarget(node, own, common)
            case node
            when Hash
              ref = node["$ref"]
              if ref.is_a?(String) && (m = ref.match(%r{\A#/\$defs/([^/]+)\z})) && !own.include?(m[1]) &&
                 common.include?(m[1])
                node["$ref"] = "common_types.json#/$defs/#{m[1]}"
              end
              node.each do |key, value|
                retarget(value, own, common) unless %w[const enum default examples].include?(key)
              end
            when Array then node.each { |value| retarget(value, own, common) }
            end
          end

          def root(version) = VERSIONS.fetch(version).then { |spec| spec[:base] + spec[:root] }

          def ours(version) = (@ours ||= {})[version] ||= Schema.new(documents: documents(version), root: root(version))

          def oracle(version)
            require "json_schemer"
            (@oracles ||= {})[version] ||= begin
              docs = documents(version)
              JSONSchemer.schema({ "$schema" => Schema::DIALECT, "$ref" => root(version) },
                                 base_uri: URI("https://oracle.invalid/root.json"), regexp_resolver: "ecma",
                                 ref_resolver: proc { |uri| docs.fetch(uri.to_s.sub(/#.*\z/, "")) })
            end
          end

          def messages(version)
            (@messages ||= {})[version] ||= Dir[File.join(UPSTREAM, VERSIONS.fetch(version)[:examples], "*.json")]
                                            .flat_map { |file| JSON.parse(File.read(file))["messages"] }
          end
        end

        def assert_agree(ours, oracle, instance, label)
          expected = oracle.valid?(instance)
          verdict = ours.valid?(instance)

          assert_equal expected, verdict,
                       "#{label}: #{JSON.generate(instance)[0, 300]} #{ours.errors(instance).first(3)}"
          assert_equal verdict, ours.errors(instance).empty?, "#{label}: errors agree with valid?"
          expected
        end

        def test_every_example_message_agrees
          counts = VERSIONS.keys.to_h do |version|
            ours = self.class.ours(version)
            oracle = self.class.oracle(version)
            [version, self.class.messages(version).each_with_index.count do |message, i|
              !assert_agree(ours, oracle, message, "#{version} example #{i}")
            end]
          end

          assert_equal 43, Dir[File.join(UPSTREAM, VERSIONS["v1_0"][:examples], "*.json")].size
          assert_equal 44, Dir[File.join(UPSTREAM, VERSIONS["v0_9"][:examples], "*.json")].size
          assert_equal({ "v0_9" => 1, "v1_0" => 0 }, counts,
                       "only v0.9's 37_native-grid (a custom component) is invalid")
        end

        def test_seeded_mutants_agree
          rng = Random.new(2026)
          invalid = 0
          total = 0
          VERSIONS.each_key do |version|
            ours = self.class.ours(version)
            oracle = self.class.oracle(version)
            self.class.messages(version).each_with_index do |message, i|
              mutant, what = mutate(message, rng)
              total += 1
              invalid += 1 unless assert_agree(ours, oracle, mutant, "#{version} example #{i} mutant (#{what})")
            end
          end

          assert_operator invalid, :>, total / 3, "the mutants exercise the failing paths"
        end

        def test_catalog_documents_agree_against_the_catalog_meta_schema
          require "json_schemer"
          spec = VERSIONS.fetch("v1_0")
          drafts = JSONSchemer::Draft202012::Meta::SCHEMAS.to_h { |uri, schema| [uri.to_s, schema] }
          drafts[JSONSchemer::Draft202012::BASE_URI.to_s] = JSONSchemer::Draft202012::SCHEMA
          docs = Dir[File.join(UPSTREAM, spec[:dir], "*.json")].to_h do |file|
            [spec[:base] + File.basename(file), JSON.parse(File.read(file))]
          end.merge(drafts)
          meta_uri = "#{spec[:base]}catalog_definition.json"
          ours = Schema.new(documents: docs, root: meta_uri)
          resolver = proc { |uri| docs.fetch(uri.to_s.sub(/#.*\z/, "")) }
          oracle = JSONSchemer.schema(docs.fetch(meta_uri), regexp_resolver: "ecma", ref_resolver: resolver)
          rng = Random.new(7)
          catalogs = [spec[:catalog], "conformance/test_data/catalogs/custom_catalog_v1_0.json"]
                     .map { |path| JSON.parse(File.read(File.join(UPSTREAM, path))) }

          catalogs.each_with_index { |catalog, i| assert assert_agree(ours, oracle, catalog, "catalog #{i}") }
          20.times do |i|
            mutant, what = mutate(catalogs[0], rng)

            assert_agree(ours, oracle, mutant, "catalog mutant #{i} (#{what})")
          end
        end

        # Strings for each asserted format, the URI ones with a query that
        # still reads as a pattern: the oracle's `regex` check scans tokens
        # without compiling, so it takes a leading quantifier and `{,3}`,
        # which ECMA-262's unicode mode refuses (and this validator with it).
        FORMAT_SAMPLES = ["https://a2ui.org/x?q=1#f", "urn:isbn:1", "mailto:a@b.c", "/relative", "#frag", "/x?a=b",
                          "/x?a b", "x y", "http://[bad", "%zz", "", "2026-10-29T12:00:00Z", "1998-12-31T23:59:60Z",
                          "2026-10-29t12:00:00.5+02:00", "1998-12-31T12:59:60Z", "2026-10-29T24:00:00Z",
                          "2026-13-01T00:00:00Z", "2026-10-29T12:00:00", "2026-02-28", "2026-02-30", "2026-2-1",
                          "12:00:00Z", "23:59:60Z", "12:00:00.25-05:00", "12:00:00", "25:00:00Z", "^a+$", "(", "\\A",
                          "(?<=a)b", "[a-z]{2,}"].freeze

        def test_asserted_formats_agree
          require "json_schemer"
          Schema::FORMATS.each_key do |format|
            ours = Schema.new(documents: { "https://example.test/f" => { "format" => format } },
                              root: "https://example.test/f")
            oracle = JSONSchemer.schema({ "format" => format }, regexp_resolver: "ecma")

            FORMAT_SAMPLES.each { |sample| assert_agree(ours, oracle, sample, "format #{format}") }
          end
        end

        private

        # One mutation of a deep copy: a key deleted, a value retyped, a key
        # added, a string swapped, or an array emptied or grown.
        def mutate(original, rng)
          copy = JSON.parse(JSON.generate(original))
          containers = nodes(copy)
          case %i[delete retype add swap array].sample(random: rng)
          when :delete
            hash = containers.grep(Hash).reject(&:empty?).sample(random: rng) or return [copy, "noop"]
            [copy, "delete #{hash.delete(key = hash.keys.sample(random: rng)) && key}"]
          when :retype
            node = containers.reject(&:empty?).sample(random: rng) or return [copy, "noop"]
            key = node.is_a?(Hash) ? node.keys.sample(random: rng) : rng.rand(node.size)
            node[key] = JSON.parse(JSON.generate(value = VALUES.sample(random: rng)))
            [copy, "set #{key} = #{JSON.generate(value)}"]
          when :add
            hash = containers.grep(Hash).sample(random: rng) or return [copy, "noop"]
            hash[key = KEYS.sample(random: rng)] = JSON.parse(JSON.generate(value = VALUES.sample(random: rng)))
            [copy, "add #{key} = #{JSON.generate(value)}"]
          when :swap
            holder, key = strings(copy).sample(random: rng) || (return [copy, "noop"])
            holder[key] = STRINGS.sample(random: rng)
            [copy, "string #{key} = #{holder[key].inspect}"]
          else
            list = containers.grep(Array).sample(random: rng) or return [copy, "noop"]
            list.empty? || rng.rand < 0.5 ? list.clear : list << JSON.parse(JSON.generate(list.first))
            [copy, "array #{list.size}"]
          end
        end

        def nodes(value, acc = [])
          acc << value if value.is_a?(Hash) || value.is_a?(Array)
          case value
          when Hash then value.each_value { |v| nodes(v, acc) }
          when Array then value.each { |v| nodes(v, acc) }
          end
          acc
        end

        def strings(value, acc = [])
          case value
          when Hash then value.each { |k, v| v.is_a?(String) ? acc << [value, k] : strings(v, acc) }
          when Array then value.each_with_index { |v, i| v.is_a?(String) ? acc << [value, i] : strings(v, acc) }
          end
          acc
        end
      end
    end
  end
end
