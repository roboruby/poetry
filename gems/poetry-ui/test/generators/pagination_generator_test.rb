# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/poetry/pagination/pagination_generator"

# The adapters detect via defined?() - the test group carries the gems,
# but nothing else in the suite loads them.
require "kaminari"
require "pagy"
require "will_paginate"

module Poetry
  # The poetry:pagination generator: explicit-arg installs, detection mode
  # (all three paginators live in the test group), and the fail-fast paths.
  class PaginationGeneratorTest < Rails::Generators::TestCase
    tests Poetry::Generators::PaginationGenerator
    destination File.expand_path("../tmp/pagination_generator", __dir__)
    setup :prepare_destination

    def test_kaminari_installs_the_monolithic_paginator
      run_generator %w[kaminari]

      assert_file "app/views/kaminari/_paginator.html.erb" do |content|
        assert_match(/poetry_pagination/, content)
        assert_match(/page_url_for/, content)
        assert_match(/poetry owns the window/, content)
      end
    end

    def test_pagy_installs_the_nav_helper
      run_generator %w[pagy]

      assert_file "app/helpers/poetry_pagy_helper.rb" do |content|
        assert_match(/def poetry_pagy_nav/, content)
        assert_match(/pagy\.page_url/, content)
        assert_match(/>= 43/, content)
      end
    end

    def test_will_paginate_installs_the_renderer
      run_generator %w[will_paginate]

      assert_file "app/lib/poetry_link_renderer.rb" do |content|
        assert_match(/class PoetryLinkRenderer < WillPaginate::ActionView::LinkRenderer/, content)
        assert_match(/def to_html/, content)
      end
    end

    def test_detection_mode_installs_every_loaded_paginator
      run_generator

      assert_file "app/views/kaminari/_paginator.html.erb"
      assert_file "app/helpers/poetry_pagy_helper.rb"
      assert_file "app/lib/poetry_link_renderer.rb"
    end

    def test_unknown_paginator_fails_fast
      output = capture(:stderr) { run_generator %w[bootstrap_paginate] }

      assert_match(/unknown paginator/, output)
      assert_no_file "app/views/kaminari/_paginator.html.erb"
    end
  end
end
