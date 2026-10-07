# poetry-jumpstart_pro

Re-skin a [Jumpstart Pro](https://jumpstartrails.com) app with
[Poetry](https://github.com/roboruby/poetry) components: accessible,
themeable from one design source, and agent-legible.

> **License note.** Jumpstart Pro is commercial. This gem ships **only
> Poetry-native recreations** of the screens (created with the Jumpstart Pro
> author's explicit permission), never Jumpstart's source. It installs them as
> **host `app/views/` overrides**, which Rails resolves ahead of the Jumpstart
> engine's originals, so your licensed Jumpstart source is never touched.

## Requirements

- Jumpstart Pro on Rails 8 authentication (the `users/*` sign in screens).
- Poetry at the same version as this gem (`gem "poetry"`; the family releases in lockstep), Ruby 3.4 or later.

## Install

```ruby
# Gemfile (in your Jumpstart Pro app)
gem "poetry"
gem "poetry-jumpstart_pro", group: :development
```

```bash
bundle install
bin/rails g poetry_jumpstart_pro:install   # every category; runs poetry:install if needed
bin/rails tailwindcss:build
bin/rails poetry:check
bin/rails test && bin/rails test:system
```

Pass category names to install a subset (`bin/rails g
poetry_jumpstart_pro:install auth shell`). Every installed file is yours to
edit; delete an override to fall back to Jumpstart's view. Re-running is
safe: identical files are skipped and every edit below is idempotent.

## What the installer does

1. **Reconciles the stylesheets.** Jumpstart's CSS declares a few things
   globally that would win over Poetry's tokens and components. The forms
   plugin moves to the class strategy, Jumpstart's `--color-primary` mapping
   and `--background` declarations give way to Poetry's tokens, the bare
   `a`, `ul` and `ol` rules leave `components/base.css`, and the bare heading,
   `code` and `kbd` rules in `components/typography.css` skip Poetry's
   components (elements with `data-slot`).
2. **Installs Poetry** with `bin/rails g poetry:install` when the app has no
   Poetry tokens yet (`--theme` picks the theme).
3. **Copies the views** for each category into `app/views/`. In development
   Jumpstart copies a few default views into `app/views/` on boot (the
   layout, `_head`, the left and right nav, the dashboard, the landing and
   about pages, the agreements); an untouched copy is replaced without a
   prompt, an edited one prompts like any Rails generator conflict.
4. **Adds `app/helpers/poetry_jumpstart_pro_helper.rb`**:
   `poetry_pagination_nav(@page)` draws Jumpstart's pagination page as
   `poetry_pagination`, and `poetry_toast_variant` maps Jumpstart's toast
   icons onto Poetry's toast variants.
5. **Styles the admin** (madmin category): `Madmin.stylesheets << "tailwind"`
   in `config/initializers/madmin.rb`.
6. **Updates Jumpstart's own tests** that assert on replaced markup: the sign
   in helpers click `[name="commit"]` (Poetry's submit is a button), and the
   pagination test reads Poetry's `nav[aria-label=pagination]`.

The layouts stay Jumpstart's. The page's one `poetry_toaster` lives in the
flash partial, which every Jumpstart layout renders once.

Options: `--skip-stylesheets`, `--skip-tests`, `--skip-poetry-install`,
`--theme NAME`, plus the usual generator flags (`--force`, `--skip`,
`--pretend`).

## Categories

| Category | Screens |
|----------|---------|
| `auth` | Sign in, two-factor challenge, sign up, profile, password reset, sudo, OAuth buttons, form errors |
| `shell` | Navbar and its Hotwire Native variant, left and right nav, account, user and dev menus, notifications, flash and toaster, footer |
| `accounts` | Accounts index, show, new, edit and form, members, invitations, transfer, account password, the settings navigation |
| `users` | Mention chip, agreements, connected accounts, referrals, two-factor backup codes |
| `api_tokens` | API tokens index, show, new, edit and form |
| `notifications` | Notifications index, the navbar panel and the row |
| `announcements` | Announcements index, show and the row |
| `checkouts` | The checkout page and its testimonial |
| `public` | Landing, about, privacy, terms |
| `dashboard` | The signed-in home |
| `errors` | 404, 500 and the generic error page |
| `billing` | Billing overview, email, info, charges, subscriptions (plan, summary, change, cancel, resume, upcoming, payment method), pricing |
| `madmin` | Admin dashboard and the array field |

Seventy-nine templates in all. Some views stay Jumpstart's because they
cannot be recreated without copying: the checkout processor forms, the
Braintree and PayPal payment method forms, the agreement content partials
and the mention list.

## Development

```bash
bundle install
bundle exec rake
```

The suite validates the generator, the stylesheet and test edits, and the
templates. Point it at your own licensed Jumpstart Pro checkout to add the
drift guard (every template shadows a view the engine ships), the license
guard (no template is a near copy of its original) and the translation check
(every key without a default exists in Jumpstart's English locale):

```bash
JUMPSTART_PRO_PATH=/path/to/jumpstart-pro-rails bundle exec rake
```

Those checks skip cleanly when the variable is unset. The Jumpstart repo is
never copied into or committed to this project.

## License

Available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
The license covers the Poetry recreations this gem ships; it does not
contain (and grants no rights to) Jumpstart Pro's own source.
