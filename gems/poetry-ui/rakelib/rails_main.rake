# frozen_string_literal: true

# The Rails main leg: the suite and the behaviour tier on the Rails that
# comes next, in a host that compiles its HTML templates through Herb, the
# way an app on the next framework defaults does. What breaks there is
# known here before a release carries it to a host.
#
# Kept out of `default`: it needs the network, and Rails main can break for
# reasons of its own. CI runs it as a job that reports without blocking.
namespace :test do
  desc "Run the suite and the behaviour tier on Rails main, templates compiled through Herb"
  task :rails_main do
    gemfile = File.expand_path("../gemfiles/rails_main.gemfile", __dir__)

    Bundler.with_unbundled_env do
      environment = { "BUNDLE_GEMFILE" => gemfile, "COVERAGE" => "0" }
      sh(environment, "bundle check > /dev/null || bundle install")
      sh(environment, "bundle exec rake test test:dommy")
    end
  end
end
