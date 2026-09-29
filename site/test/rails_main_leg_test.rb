# frozen_string_literal: true

require "test_helper"

# The Rails main leg (gemfiles/rails_main.gemfile) has to be what it says.
# A run that resolved a released Rails, or compiled through Erubi, would
# pass every other test and prove nothing, so the leg checks its own
# footing. A plain run defines no test here.
class RailsMainLegTest < ActiveSupport::TestCase
  if ENV["POETRY_RAILS"] == "main"
    test "the bundle resolved Rails from its main branch" do
      assert_predicate Rails.gem_version, :prerelease?
      assert_includes Gem.loaded_specs.fetch("rails").full_gem_path, "bundler/gems/rails-"
    end

    test "the application loaded the next framework defaults" do
      assert_equal "8.2", Rails.application.config.loaded_config_version.to_s
    end

    test "HTML templates compile through Herb" do
      assert_operator ActionView::Template::Handlers::ERB.erb_implementation, :<=, ::Herb::Engine
      assert_predicate Poetry::Core::Check::Compile, :rendering?
    end
  end
end
