# The docs run on the poetry family's working trees when they are checked
# out beside this repo (Gemfile.siblings, nothing pinned); anywhere else, and
# whenever BUNDLE_GEMFILE is set explicitly, on the release pinned in Gemfile.
siblings = File.directory?(File.expand_path("../../poetry-core", __dir__))
ENV["BUNDLE_GEMFILE"] ||= File.expand_path(siblings ? "../Gemfile.siblings" : "../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
