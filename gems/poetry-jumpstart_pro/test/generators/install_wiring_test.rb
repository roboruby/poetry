# frozen_string_literal: true

require "test_helper"

# The steps around the views: the helper, the stylesheet reconciliation,
# Madmin's stylesheet, the test selectors and the Poetry check. The
# host files here are synthetic stand-ins with the same shape as
# Jumpstart's, never copies of them.
class InstallWiringTest < InstallGeneratorTest
  destination File.expand_path("../../tmp/install_wiring", __dir__)

  ENTRY = <<~CSS
    @import "tailwindcss";
    @import "./poetry/tokens.css" layer(theme);

    @plugin "@tailwindcss/forms";
    @plugin "@tailwindcss/typography";

    @theme {
      --color-primary: var(--bg-primary);
      --color-gray-50: var(--color-neutral-50);
    }
  CSS

  THEME = <<~CSS
    :root {
      --bg-primary: var(--color-blue-600);
      --background: var(--color-white);
      --divider-color: var(--color-gray-100);
    }
  CSS

  BASE = <<~CSS
    body {
      display: grid;
    }

    a {
      color: var(--base-text);
      text-decoration: underline;
    }

    @supports (color: color-mix(in lab, red, red)) {
      a {
        text-decoration-color: color-mix(in oklab, var(--base-text), transparent 80%);
      }
    }

    ul {
      list-style-type: disc;
    }

    .table {
      width: 100%;
    }
  CSS

  PAGINATION_TEST = <<~TEST
    assert_select "nav.pagination a[rel=next][href=?]", "/accounts?page=2"
    assert_select "nav.pagination a[rel=prev][href=?]", "/accounts"
  TEST

  setup do
    write_host_file("app/assets/tailwind/application.css", ENTRY)
    write_host_file("app/assets/tailwind/themes/light.css", THEME)
    write_host_file("app/assets/tailwind/themes/dark.css", THEME)
    write_host_file("app/assets/tailwind/components/base.css", BASE)
    write_host_file("app/assets/tailwind/components/typography.css", "h2, .h2 {\n  font-size: 2rem;\n}\n")
    write_host_file("config/initializers/madmin.rb", %(Madmin.site_name = "Example"\n))
    write_host_file("test/application_system_test_case.rb",
                    %(def login_as(user)\n  find('input[name="commit"]').click\nend\n))
    write_host_file("test/system/login_system_test.rb", %(test "otp" do\n  find('input[name="commit"]').click\nend\n))
    write_host_file("test/controllers/concerns/pagination_test.rb", PAGINATION_TEST)
  end

  test "the pagination and toast helper lands in app/helpers" do
    run_generator %w[shell]

    assert_file "app/helpers/poetry_jumpstart_pro_helper.rb", /module PoetryJumpstartProHelper/
  end

  test "the stylesheets are reconciled with Poetry" do
    run_generator %w[shell]
    entry = read_host_file("app/assets/tailwind/application.css")

    assert_includes entry, "strategy: class;"
    refute_includes entry, "--color-primary: var(--bg-primary);"
    refute_includes read_host_file("app/assets/tailwind/themes/light.css"), "--background: var(--color-white);"

    base = read_host_file("app/assets/tailwind/components/base.css")

    refute_match(/^a \{/, base)
    refute_match(/^ul \{/, base)
    refute_includes base, "@supports"
    assert_includes base, "body {"
    assert_includes base, ".table {"
    assert_includes read_host_file("app/assets/tailwind/components/typography.css"), "h2:not([data-slot]), .h2 {"
  end

  test "re-running leaves the reconciled stylesheets alone" do
    run_generator %w[shell]
    first = Poetry::JumpstartPro::Stylesheets::FILES.keys.to_h { |relative| [relative, read_host_file(relative)] }
    run_generator %w[shell]

    first.each { |relative, content| assert_equal content, read_host_file(relative), relative }
  end

  test "--skip-stylesheets leaves Jumpstart's CSS untouched" do
    run_generator %w[shell --skip-stylesheets]

    assert_equal ENTRY, read_host_file("app/assets/tailwind/application.css")
    assert_equal BASE, read_host_file("app/assets/tailwind/components/base.css")
  end

  test "the madmin category adds the app stylesheet to Madmin, once" do
    run_generator %w[madmin]
    run_generator %w[madmin]

    assert_equal 1, read_host_file("config/initializers/madmin.rb").scan(PoetryJumpstartPro::InstallGenerator::MADMIN_STYLESHEET).size
  end

  test "Madmin is left alone without the madmin category" do
    run_generator %w[shell]

    refute_includes read_host_file("config/initializers/madmin.rb"), "stylesheets"
  end

  test "the auth category points the sign in test helpers at any commit element" do
    run_generator %w[auth]
    %w[test/application_system_test_case.rb test/system/login_system_test.rb].each do |relative|
      source = read_host_file(relative)

      assert_includes source, %(find('[name="commit"]'))
      refute_includes source, %(input[name="commit"])
    end
  end

  test "the accounts category points the pagination test at Poetry's nav" do
    run_generator %w[accounts]
    source = read_host_file("test/controllers/concerns/pagination_test.rb")

    assert_includes source, %(assert_select "nav[aria-label=pagination] a[href=?]", "/accounts?page=2")
    assert_includes source, %(assert_select "nav[aria-label=pagination] a[href=?]", "/accounts")
    refute_includes source, "nav.pagination"
  end

  test "test edits follow their category" do
    run_generator %w[accounts]

    assert_includes read_host_file("test/application_system_test_case.rb"), %(input[name="commit"])
  end

  test "--skip-tests leaves the system tests untouched" do
    run_generator %w[auth --skip-tests]

    assert_includes read_host_file("test/application_system_test_case.rb"), %(input[name="commit"])
  end

  # Jumpstart copies its default views into app/views on a development
  # boot; an untouched copy is the engine's own view, so it is replaced.
  test "an untouched Jumpstart default copy is replaced without a prompt" do
    write_host_file("lib/jumpstart/app/views/dashboard/show.html.erb", "<h1>engine default</h1>\n")
    write_host_file("app/views/dashboard/show.html.erb", "<h1>engine default</h1>\n")
    run_generator %w[dashboard]

    assert_file "app/views/dashboard/show.html.erb", /Poetry recreation of Jumpstart's dashboard/
  end

  test "an edited copy is the app's own and is not forced" do
    write_host_file("lib/jumpstart/app/views/dashboard/show.html.erb", "<h1>engine default</h1>\n")
    write_host_file("app/views/dashboard/show.html.erb", "<h1>our dashboard</h1>\n")
    run_generator %w[dashboard --skip]

    assert_file "app/views/dashboard/show.html.erb", "<h1>our dashboard</h1>\n"
  end

  test "a run without Poetry's entry import counts as not installed" do
    write_host_file("app/assets/tailwind/application.css", %(@import "tailwindcss";\n))
    output = run_generator %w[dashboard --skip-poetry-install]

    assert_match(/poetry:install/, output)
  end

  test "without Poetry and with --skip-poetry-install it says what to run" do
    FileUtils.rm_f(File.join(destination_root, PoetryJumpstartPro::InstallGenerator::POETRY_TOKENS))
    output = run_generator %w[auth --skip-poetry-install]

    assert_match(/poetry:install/, output)
    assert_file "app/views/users/sessions/new.html.erb"
  end
end
