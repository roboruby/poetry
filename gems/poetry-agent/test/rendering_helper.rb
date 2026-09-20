# frozen_string_literal: true

# Boots the dummy Rails host (poetry-core, poetry-ui, poetry-lucide,
# poetry-agent) for the tests that render components; require it after
# test_helper, only where a view context is needed.
ENV["RAILS_ENV"] = "test"
require_relative "dummy/config/environment"

module RenderingHelper
  # @return [ActionView::Base] a view context with the component helpers
  def view_context
    @view_context ||= ApplicationController.new.tap { |c| c.request = ActionDispatch::TestRequest.create }.view_context
  end
end

Minitest::Test.include RenderingHelper
