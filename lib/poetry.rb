# frozen_string_literal: true

require "zeitwerk"
require_relative "poetry/version"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/poetry/version.rb")
loader.setup

module Poetry
  class Error < StandardError; end
end
