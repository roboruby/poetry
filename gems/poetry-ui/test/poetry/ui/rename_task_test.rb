# frozen_string_literal: true

require "test_helper"
require "rake"

module Poetry
  module Ui
    # `bin/rails poetry:rename`: the renames poetry:check warns about,
    # applied to the templates it points at.
    class RenameTaskTest < Minitest::Test
      def setup
        @dir = Rails.root.join("tmp/rename_task_test")
        @dir.mkpath
        @file = @dir.join("show.html.erb")
        @file.write(<<~ERB)
          <%= poetry_icon(name: :"trash-2") %>
          <%= poetry_icon(name: :"trash-2") %> <%= poetry_icon(name: :"trash-2") %>
          <%= poetry_icon(name: :plus) %>
        ERB
      end

      def teardown
        FileUtils.remove_entry(@dir)
        ENV.delete("DRY_RUN")
      end

      def run_task
        capture_io do
          Rake.with_application do |rake|
            rake.define_task(Rake::Task, :environment)
            load File.expand_path("../../../lib/tasks/poetry/rename.rake", __dir__)
            rake["poetry:rename"].invoke("tmp/rename_task_test/*.html.erb")
          end
        end
      end

      def test_it_rewrites_a_renamed_icon_and_leaves_what_it_cannot_place
        output, errors = run_task

        assert_equal <<~ERB, @file.read
          <%= poetry_icon(name: :trash) %>
          <%= poetry_icon(name: :"trash-2") %> <%= poetry_icon(name: :"trash-2") %>
          <%= poetry_icon(name: :plus) %>
        ERB
        assert_includes output, "tmp/rename_task_test/show.html.erb:1: trash-2 -> trash"
        assert_includes output, "poetry:rename: 1 rename made, 1 left for you"
        assert_includes errors, "show.html.erb:2: trash-2 left as it is (written 2 times on this line)"
      end

      def test_a_dry_run_lists_the_renames_and_writes_nothing
        ENV["DRY_RUN"] = "1"
        before = @file.read
        output, = run_task

        assert_equal before, @file.read
        assert_includes output, "show.html.erb:1: trash-2 -> trash"
        assert_includes output, "poetry:rename: 1 rename to make"
      end
    end
  end
end
