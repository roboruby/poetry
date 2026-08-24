# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Stimulus
      class DeclarationsTest < ActiveSupport::TestCase
        test "symbols resolve by exact catalog match" do
          assert_equal "poetry--core--accordion",
                       Declarations.resolve_identifier(:"poetry--core--accordion")
        end

        test "symbols resolve by unique suffix" do
          assert_equal "poetry--core--accordion", Declarations.resolve_identifier(:accordion)
          assert_equal "poetry--core--action-bar", Declarations.resolve_identifier(:action_bar)
        end

        test "unknown symbols raise listing the catalog" do
          error = assert_raises(Declarations::DeclarationError) do
            Declarations.resolve_identifier(:zzz_missing)
          end
          assert_match(/unknown stimulus controller/, error.message)
          assert_match(/host-app controller/, error.message)
        end

        test "ambiguous suffixes raise listing the candidates" do
          catalog = Manifest.instance_variable_get(:@catalog)
          Manifest.instance_variable_set(:@catalog, {
                                           "poetry--core--widget" => {},
                                           "poetry--charts--widget" => {}
                                         })

          error = assert_raises(Declarations::DeclarationError) do
            Declarations.resolve_identifier(:widget)
          end
          assert_match(/ambiguous stimulus controller/, error.message)
          assert_match(/poetry--charts--widget/, error.message)
        ensure
          Manifest.instance_variable_set(:@catalog, catalog)
        end

        test "strings and arrays pass through the Builder's formatting" do
          assert_equal "checkout", Declarations.resolve_identifier("checkout")
          assert_equal "admin--panel", Declarations.resolve_identifier(%i[admin panel])
        end

        test "event_name validates against the emitting controller" do
          assert_equal "poetry:accordion:change",
                       Declarations.event_name(:accordion, :change)
          assert_raises(Declarations::DeclarationError) do
            Declarations.event_name(:accordion, :vanished)
          end
        end

        test "event_name skips validation for host controllers" do
          assert_equal "checkout:paid", Declarations.event_name("checkout", :paid)
        end

        test "camelize maps snake_case and passes camelCase through" do
          assert_equal "sideOffset", Declarations.camelize(:side_offset)
          assert_equal "pressStart", Declarations.camelize(:pressStart)
        end

        test "a value takes one of a literal or from" do
          wiring = Declarations::Wiring.new(identifier: "checkout", conditions: nil, entries: [])
          dsl = Declarations::WiringDSL.new("Test", wiring)

          assert_raises(Declarations::DeclarationError) { dsl.value(:x, 1, from: :y) }
        end
      end
    end
  end
end
