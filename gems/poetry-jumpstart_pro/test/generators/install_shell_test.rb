# frozen_string_literal: true

require "test_helper"

class InstallShellTest < InstallGeneratorTest
  destination File.expand_path("../../tmp/install_shell", __dir__)

  EXPECTED = %w[
    application/_account_menu.html.erb
    application/_dev_menu.html.erb
    application/_flash.html.erb
    application/_footer.html.erb
    application/_left_nav.html.erb
    application/_navbar.html+native.erb
    application/_navbar.html.erb
    application/_notifications.html.erb
    application/_right_nav.html.erb
    application/_user_menu.html.erb
  ].freeze

  test "the shell category is exactly the expected chrome" do
    assert_equal EXPECTED, TemplateTree.views("shell").sort
  end

  test "install shell writes the app-shell chrome overrides" do
    run_generator %w[shell]

    EXPECTED.each { |relative| assert_file "app/views/#{relative}" }
  end

  # A host _navbar.html.erb shadows the engine's native variant, so the
  # variant has to ship beside it.
  test "the navbar ships its Hotwire Native variant" do
    run_generator %w[shell]

    assert_file "app/views/application/_navbar.html+native.erb", /toggle-nav-bar@window->toggle#toggle/
  end

  # Every Jumpstart layout renders the flash partial once, so the page's one
  # toaster lives there and the layouts stay Jumpstart's.
  test "the flash partial carries the single toaster" do
    run_generator %w[shell]
    assert_file "app/views/application/_flash.html.erb" do |source|
      assert_equal 1, source.scan("<%= poetry_toaster %>").size
    end
  end

  # A submit menu item is a button inside a display:contents form, which
  # sizes to its label unless told to fill the row.
  test "the sign out item fills the menu row" do
    run_generator %w[shell]

    assert_file "app/views/application/_user_menu.html.erb",
                /with_item\(submit: session_path, method: :delete, class: "w-full"\)/
  end

  test "installing auth and shell together is additive" do
    run_generator %w[auth shell]

    assert_file "app/views/users/sessions/new.html.erb"
    assert_file "app/views/application/_flash.html.erb"
    assert_file "app/views/application/_footer.html.erb"
  end
end
