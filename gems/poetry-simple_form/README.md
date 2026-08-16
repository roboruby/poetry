# poetry-simple_form

The **migration bridge** from simple_form to poetry. One initializer re-maps
simple_form's input types onto classes that render whole poetry Fields
through `Poetry::Ui::FormBuilder` — existing `f.input` calls keep working,
now with the quartet (label / hint / error / aria) derived from the model
exactly like the native builder, because the shim renders *through* it.

```ruby
# Gemfile
gem "poetry-simple_form"
```

```sh
bin/rails g poetry:simple_form:install   # writes the one-line initializer
```

## What you get

- `f.input` for string/email/url/tel/search/password/text/boolean/numeric/
  date/time/file and the collection trio (select / radio_buttons /
  check_boxes) renders poetry Fields: `aria-required` (never native),
  maxlength/min/max/step from validations, errors wired via
  `aria-describedby`.
- `f.association` works unchanged (simple_form fetches the records; the
  shim's collection inputs render them as poetry pickers).
- `:datetime` falls back to stock simple_form rendering — poetry has no
  composite control yet, and a raise mid-migration would be hostile.
- Remove the initializer to restore stock rendering instantly.

## What this is not

Not the end state. The bridge exists so views can migrate to
`form_with(model:, builder: Poetry::Ui::FormBuilder)` (and `f.input`
there) at your own pace — see the poetry docs `/forms` guide. simple_form
itself contributes only type resolution here; its wrapper tree is bypassed
by design (a flat wrapper cannot express the Field quartet).

Existing `simple_form.*` i18n keys (labels/hints/placeholders) keep
working — poetry's builder reads them as a fallback chain.
