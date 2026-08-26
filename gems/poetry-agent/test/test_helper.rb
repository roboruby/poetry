# frozen_string_literal: true

require "simplecov"
SimpleCov.start { add_filter "/test/" }

require "minitest/autorun"
require "poetry/agent"
