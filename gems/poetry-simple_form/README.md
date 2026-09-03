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

- `f.input` for string/email/url/tel/search/uuid/password/text/json/boolean/
  numeric/range/date/time/file and the collection trio (select /
  radio_buttons / check_boxes), plus grouped_select and time_zone, renders
  poetry Fields: `aria-required` (never native), maxlength/min/max/step
  from validations, errors wired via `aria-describedby`.
- `f.association` works unchanged (simple_form fetches the records; the
  shim's collection inputs render them as poetry pickers).
- Every poetry form control is reachable by its poetry name through `as:`,
  even the ones simple_form never had: `:switch`, `:slider`, `:otp`,
  `:sensitive`, `:tag_group`, `:date_picker`, `:calendar`, `:combobox`,
  `:autocomplete`, `:native_select`.
- `required: true/false` overrides the model's presence inference; `label_method:`
  and `value_method:` (symbols or callables) are honored on every collection
  input, with simple_form's detection chain as the fallback.
- Poetry-only options ride a `poetry:` hash - `f.input :active, poetry:
  { switch: true }`, `f.input :code, as: :otp, poetry: { length: 4 }` -
  merged last, so it wins over anything simple_form derived. `input_html`
  still lands on the control (minus class and id, which the component owns).
- `:datetime` renders poetry's DateTimeField (one datetime-local control,
  local wall time on the wire). `:rich_text_area`, `:hidden`, and `:country`
  fall back to stock simple_form rendering on purpose (no editor, nothing to
  render, and a country list poetry does not carry).
- Remove the initializer to restore stock rendering instantly.

The full type-to-component table is `Poetry::SimpleForm::COVERAGE`; a
parity test in this gem fails when a new poetry form control has no
simple_form route, so the two vocabularies cannot drift apart.

## What this is not

Not the end state. The bridge exists so views can migrate to
`form_with(model:, builder: Poetry::Ui::FormBuilder)` (and `f.input`
there) at your own pace — see the poetry docs `/forms` guide. simple_form
itself contributes only type resolution here; its wrapper tree is bypassed
by design (a flat wrapper cannot express the Field quartet).

Existing `simple_form.*` i18n keys (labels/hints/placeholders) keep
working — poetry's builder reads them as a fallback chain.

## License

Available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
