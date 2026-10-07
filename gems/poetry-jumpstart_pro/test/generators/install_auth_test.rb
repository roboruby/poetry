# frozen_string_literal: true

require "test_helper"

class InstallAuthTest < InstallGeneratorTest
  destination File.expand_path("../../tmp/install_auth", __dir__)

  # Every view the auth category installs, relative to app/views: the Rails
  # 8 authentication screens Jumpstart Pro ships today.
  EXPECTED = %w[
    application/_error_messages.html.erb
    users/passwords/edit.html.erb
    users/passwords/new.html.erb
    users/registrations/edit.html.erb
    users/registrations/new.html.erb
    users/sessions/new.html.erb
    users/sessions/otps/new.html.erb
    users/shared/_oauth.html.erb
    users/sudo/new.html.erb
    users/two_factor/verify.html.erb
  ].freeze

  test "the auth category is exactly the expected screens" do
    assert_equal EXPECTED, TemplateTree.views("auth").sort
  end

  test "install auth writes the poetry override views into app/views" do
    run_generator %w[auth]

    EXPECTED.each { |relative| assert_file "app/views/#{relative}" }
  end

  test "an unknown category is skipped, not fatal" do
    output = run_generator %w[does_not_exist]

    assert_match(/skip/, output)
    assert_no_file "app/views/users/sessions/new.html.erb"
  end

  test "the sign in and two factor submits are named commit" do
    run_generator %w[auth]

    %w[users/sessions/new.html.erb users/sessions/otps/new.html.erb].each do |relative|
      assert_file "app/views/#{relative}", /name: "commit"/
    end
  end

  # --- drift guard: validated against a real, private Jumpstart checkout ---

  test "each override shadows a view that exists in the real Jumpstart engine" do
    skip "set JUMPSTART_PRO_PATH to test against your Jumpstart Pro checkout" unless JumpstartRepo.path

    EXPECTED.each do |relative|
      original = JumpstartRepo.original_for(relative)

      assert_path_exists original, "override app/views/#{relative} has no counterpart at #{original} - " \
                                   "the port may have drifted from Jumpstart"
    end
  end

  test "the auth screens target routes Jumpstart actually draws" do
    routes = JumpstartRepo.routes or skip("set JUMPSTART_PRO_PATH")

    {
      "login_path" => /as: :login/,
      "signup_path" => /as: :signup/,
      "session_path" => /resource :session\b/,
      "session_otp_path" => /resource :otp\b/,
      "registration_path" => /resource :registration\b/,
      "passwords_path" => /resources :passwords\b/,
      "sudo_path" => /post :sudo\b/,
      "user_two_factor_path" => /resource :two_factor\b/
    }.each do |helper, route|
      assert_match route, routes, "#{helper} needs #{route.source} in Jumpstart's routes"
    end
  end
end
