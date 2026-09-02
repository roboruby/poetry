# frozen_string_literal: true

require "test_helper"
require "open3"

module Poetry
  module Charts
    # The helper include must survive a host that loads ActionView before the
    # app initializes (an editor gem patching a view helper at require time):
    # the :action_view hook then fires inside the engine's initializer, before
    # app/helpers is autoloadable. Booted in a subprocess - this process is
    # already initialized, so it cannot replay the sequence itself.
    class EngineBootTest < ActiveSupport::TestCase
      ROOT = File.expand_path("../../..", __dir__)

      def test_boots_with_action_view_loaded_before_initialization
        script = 'require "action_view"; require "action_view/base"; ' \
                 'require File.join(ARGV[0], "test/dummy/config/environment"); ' \
                 'print(ActionView::Base.method_defined?(:poetry_bar_chart) ? "helper installed" : "helper missing")'
        output, status = Open3.capture2e({ "RAILS_ENV" => "test", "COVERAGE" => "0" }, Gem.ruby, "-e", script, ROOT,
                                         chdir: ROOT)

        assert_predicate status, :success?, "boot failed:\n#{output}"
        assert_includes output, "helper installed"
      end
    end
  end
end
