# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/).

## [0.1.12]

### Added

- First release. `bin/rails g poetry_jumpstart_pro:install` re-skins a Jumpstart Pro app on Rails 8 authentication with Poetry: seventy-nine view recreations in thirteen categories (auth, shell, accounts, users, api_tokens, notifications, announcements, checkouts, public, dashboard, errors, billing, madmin) install as `app/views` overrides, which Rails resolves ahead of the Jumpstart engine's originals. The checkout processor forms, the Braintree and PayPal payment method forms, the agreement content partials and the mention list stay Jumpstart's.
- The generator runs `poetry:install` when the app has no Poetry yet; reconciles Jumpstart's stylesheets with Poetry's (the forms plugin's class strategy, the primary and background tokens, the bare `a`, `ul` and `ol` rules, and heading, `code` and `kbd` rules that skip Poetry's components); installs `app/helpers/poetry_jumpstart_pro_helper.rb`, the pagination and toast adapters; adds the app stylesheet to Madmin; and updates the selectors in Jumpstart's own sign in, two-factor and pagination tests.
- Jumpstart's untouched development-boot copies of its default views are replaced without a prompt, and an edited copy prompts like any generator conflict. Every step is idempotent, so a re-run after an upgrade is safe.
- Options: `--theme`, `--skip-poetry-install`, `--skip-stylesheets` and `--skip-tests`, beside the usual generator flags.
