# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    # RegistryDrift: an app's copy of a registry item against its install
    # record and against the registry's item now.
    class RegistryDriftTest < Minitest::Test
      RECORDED = { "a.rb" => "a1", "b.rb" => "b1", "c.rb" => "c1", "d.rb" => "d1", "e.rb" => "e1",
                   "f.rb" => "f1" }.freeze

      def drift(app, current: nil, recorded: RECORDED)
        RegistryDrift.new(recorded: recorded, current: current) { |target| app[target] }
      end

      def test_without_the_registry_a_file_is_as_installed_edited_or_missing
        result = drift({ "a.rb" => "a1", "b.rb" => "mine" }, recorded: RECORDED.slice("a.rb", "b.rb", "c.rb"))

        assert_equal({ "a.rb" => :same, "b.rb" => :edited, "c.rb" => :missing }, result.files)
        refute_predicate result, :asked?
        refute_predicate result, :update?, "nothing to take from a registry that was not asked"
        assert_predicate result, :edited?
        assert_equal %w[b.rb c.rb], result.changes.keys
      end

      def test_against_the_registry_each_file_says_who_changed_it
        current = { "a.rb" => "a1", "b.rb" => "b2", "c.rb" => "c1", "d.rb" => "d2", "e.rb" => "e2", "g.rb" => "g1" }
        app = { "a.rb" => "a1", "b.rb" => "b1", "c.rb" => "mine", "d.rb" => "mine", "f.rb" => "f1" }

        result = drift(app, current: current)

        assert_equal({ "a.rb" => :same, "b.rb" => :upstream, "c.rb" => :edited, "d.rb" => :both, "e.rb" => :missing,
                       "f.rb" => :gone, "g.rb" => :added }, result.files)
        assert_predicate result, :update?
        assert_predicate result, :edited?
      end

      def test_a_file_already_in_the_registrys_form_is_the_same_whatever_the_record_says
        result = drift({ "a.rb" => "a2" }, current: { "a.rb" => "a2" }, recorded: { "a.rb" => "a1" })

        assert_equal({ "a.rb" => :same }, result.files)
        refute_predicate result, :update?
      end

      def test_an_edit_alone_is_no_update_and_a_file_with_no_record_is_kept
        edited = drift({ "a.rb" => "mine" }, current: { "a.rb" => "a1" }, recorded: { "a.rb" => "a1" })

        refute_predicate edited, :update?
        assert_predicate edited, :edited?
        unknown = drift({ "a.rb" => "theirs" }, current: { "a.rb" => "a2" }, recorded: nil)

        assert_equal({ "a.rb" => :both }, unknown.files)
      end

      def test_every_state_has_words_for_a_report
        assert_equal %i[added both edited gone missing same upstream], RegistryDrift::STATES.keys.sort
      end
    end
  end
end
