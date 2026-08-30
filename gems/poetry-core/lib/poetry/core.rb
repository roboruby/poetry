# frozen_string_literal: true

require "pathname"
require "zeitwerk"
require "active_support/concern"
require "active_model/type/symbol"
require "active_model/type/list"

ActiveModel::Type.register(:symbol, ActiveModel::Type::Symbol)
ActiveModel::Type.register(:list, ActiveModel::Type::List)

require "view_component"
require "tailwind_merge"

require_relative "core/version"

module Poetry
  # The framework layer of poetry: the Rails engine, the component DSL, and the
  # shared primitives. Concrete components live in poetry-ui.
  module Core
    class << self
      # Gem root (the directory containing lib/, app/, etc.).
      #
      # @return [Pathname]
      def root
        @root ||= Pathname.new(File.expand_path("../..", __dir__))
      end

      # The dedicated Zeitwerk loader for poetry-core's lib/ tree.
      #
      # @return [Zeitwerk::Loader]
      def loader
        @loader ||= Zeitwerk::Loader.new.tap do |loader|
          loader.tag = "poetry-core"
          loader.inflector.inflect("css" => "CSS", "html" => "HTML")
          loader.push_dir("#{root}/lib")
          loader.ignore("#{root}/lib/poetry-core.rb") # hyphenated auto-require shim
          loader.ignore("#{root}/lib/poetry/core/version.rb") # required directly above
          loader.ignore("#{root}/lib/poetry/core/engine.rb")  # required after setup
          loader.ignore("#{root}/lib/poetry/core/errors.rb")  # required after setup
          loader.setup
        end
      end
    end
  end
end

Poetry::Core.loader

require_relative "core/errors"
require_relative "core/engine"
