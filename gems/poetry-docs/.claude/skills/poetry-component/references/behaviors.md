# Behaviors - shared client behavior, declared once

A behavior is a named piece of client behavior several components share,
declared once in Ruby and used by name. Reach for one before writing the
same controller wiring by hand: it lands where you write it, in order with
the element's own controllers; its rules lead the component's agent rules;
and the registry, llms.txt, `describe_component` and the component's docs
page list it. Poetry behaviors are not Herb's client behaviors, which
follow elements the client adds and removes.

## Using one

Inside an element of `use_stimulus`, `behavior :name, **options` adds the
behavior's wiring to that element. At class level, `use_behavior :name`
records a runtime behavior (one the component's JavaScript turns on when a
layer opens) and `use_behavior :name, on: :element` adds a wired one to an
element. Every value takes `:option` (read the component's own option of
the same name), a literal, or a Hash passed through to `value` (`from:`,
`if:`, `unless:`). A behavior's event is addressed with
`event(:behavior, :name)`, so your own controller can react to it.

```ruby
use_behavior :dismissable                     # runtime: nothing to wire

use_stimulus do
  on :list do
    behavior :roving_focus, orientation: :option, loop: true
    controller(:tabs) { action :focus_activate, on: event(:roving_focus, :entry) }
  end
end
```

A name resolves through `Poetry::Core::Behavior.namespaces`, one namespace
per gem that ships behaviors. A name two namespaces define raises at class
load; pass the module itself then.

## The catalog

| Behavior | What it does | Options | Used by |
|---|---|---|---|
| `:roving_focus` | Arrow, Home and End keys move focus across the group's items; by default the group is one Tab stop. Dispatches its `entry` event as focus lands on an item. | `orientation:` (`vertical`, `horizontal`, `both`), `loop:`, `manage_tabindex:` | Tabs, ToggleGroup, RadioGroup, TagGroup, Menubar, Accordion |
| `:popper` | Positions the panel against its anchor and keeps it inside the viewport; the anchor, content and arrow targets stay on the component's own elements. | `anchor:`, `side:`, `align:`, `side_offset:`, `align_offset:`, `avoid_collisions:`, `strategy:` | Popover, Tooltip, HoverCard, DropdownMenu, ContextMenu, Menubar, Select, Combobox, Autocomplete |
| `:checked` | A click toggles the checked state and keeps the form input in step; the using component defines `form_participant?`. | none | Checkbox, Switch |
| `:file_drop` | Files arrive by drop, picker or paste and are checked against accept, size and count before they land in the native input. Its rule: the client-side limits are advisory, validate on the model too. | `accept:`, `multiple:`, `max_files:`, `max_size:`, `min_size:`, `paste:`, `overlay:`, `directory:`, `prevent_document_drop:`, `messages:` | FileInput |
| `:focus_scope` (runtime) | Focus moves into the open layer, stays inside a modal one and returns on close. | none | Popover, DropdownMenu, ContextMenu, Menubar, Select, Combobox |
| `:dismissable` (runtime) | Escape or a press outside closes the open layer, the topmost first. | none | the six above, plus Tooltip and HoverCard |
| `:entrance_animation` (poetry-charts) | Animates the chart in toward its server-computed geometry; reduced motion shows it finished. Wired only while `animate:` holds. | none | the eight animated chart families |

poetry-motion declares its effects the same way, in a
`Poetry::Motion::Behaviors` namespace (`use_behavior :animate` and the
rest); the Motion library page lists them.

## Writing one

A module extends `Poetry::Core::Behavior` and declares a name, a one-line
description, the rules agents must follow wherever it is used, and the
wiring it adds to the element. The block runs in the element DSL with the
caller's options; `behavior_value` writes a value only when the caller
passed one. A gem or an app adds its namespace once, at load.

```ruby
# app/components/acme/behaviors/sortable.rb
module Acme
  module Behaviors
    module Sortable
      extend Poetry::Core::Behavior

      behavior :sortable, "Drag a row by its handle to reorder; the order posts as hidden inputs."
      agent_rule "Pass handle: the selector of the drag handle - never make the whole row the handle."

      wiring do |handle: nil|
        controller "sortable" do          # a String until the controller joins the manifest
          register
          behavior_value :handle, handle
        end
      end
    end
  end
end

Poetry::Core::Behavior.namespaces << "Acme::Behaviors"   # once, in an initializer
```

The JavaScript side is a controller of yours; the manifest rung in
`SKILL.md` says how it joins the manifest so a Symbol identifier validates
at class load. Behavior wiring in the controller goes through the
per-connect scope: the behaviors under `@poetry/controllers/behaviors`
(`useListen`, `useEscape`, `usePortal`, `useInterval`, ...) set up in
`connect()` and the one line `teardown(this)` in `disconnect()` undoes
them.

## Documenting one

- The description is the one line the registry, llms.txt and the docs
  show: what the behavior does for the person using the page, at most
  200 characters, present tense.
- Rules are imperatives, projected verbatim into EVERY component that uses
  the behavior, ahead of that component's own `AGENT_RULES`. Write the
  rule for the behavior, never for one consumer, to the bar in
  `documentation.md` (projected strings).
- The module's YARD docblock names the controller it wires and what each
  option does; `@example` shows one `behavior :name` line.
