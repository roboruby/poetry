# Component anatomy - the canonical section order

Every poetry component class reads top to bottom in the same order.
The order is chosen so a reader meets the component the way an agent
consumes its contract: identity, vocabulary, surface, behavior,
arguments, structure, then implementation.

## The order

| # | Section | Declares |
|---|---------|----------|
| 1 | Includes & class config | `include` / `extend`, `internal_component!`, `requires_content`, `delegate`, `with_collection_parameter` |
| 2 | Constants | vocabularies first (`VARIANTS`, `SIZES`, ...), then the agent contract (`AGENT_RULES`, `REQUIRES_ANY`, `SLOT_RENDERS`) |
| 3 | Slots | `renders_one` / `renders_many` |
| 4 | Stimulus | `use_stimulus do ... end` |
| 5 | Styles & options | `style` declarations, then `option` declarations |
| 6 | Validations | `validates` / `validate` |
| 7 | Parts | `part` declarations |
| 8 | Lifecycle | `initialize`, `before_render`, `call` - in that order |
| 9 | Public methods | everything else callable from templates or callers |
| 10 | Private methods | under a single `private` |
| 11 | Nested classes | builder / internal classes, last |

## Why this order

- **Constants come before the DSL calls that read them.** Ruby
  evaluates the class body top to bottom; `style :variant, variants:
  VARIANTS` needs `VARIANTS` already defined. Putting every constant in
  one early section satisfies this everywhere at once.
- **The agent contract lives with the constants.** `AGENT_RULES`,
  `REQUIRES_ANY`, and `SLOT_RENDERS` are data the machine surfaces
  project; grouping them right after the vocabularies keeps the whole
  published contract readable in one screen.
- **Slots before behavior, behavior before arguments.** What the
  component holds (slots), how it acts (Stimulus), what it accepts
  (styles, options, validations), what it renders (parts). Each section
  answers the next question a reader has.
- **Lifecycle heads the public methods.** `initialize` is the first
  public method anyone looks for; `before_render` and `call` follow it
  so the render path reads as one block.

## Hard rules

1. **Never reorder declarations within a section.** Option, part, and
   slot order is projected into the registry and the agent surface in
   declaration order. Moving a whole section preserves it; shuffling
   inside a section changes a machine surface.
2. **One `private` keyword.** Everything below it is private; no
   interleaving public and private methods.
3. **Inner classes declare `internal_component!`** when they inherit
   the component machinery but are not published components in their
   own right.
4. **Nested classes sit at the end of the class but above the
   `private` divider.** A constant is never private-scoped, so placing
   one below `private` is misleading (and linters flag it). A nested
   class a class-body DSL call evaluates must stay above that call
   instead.
5. **`frozen_string_literal: true`** heads every file.

## Skeleton

```ruby
# frozen_string_literal: true

module MyApp
  module Callout
    # A bordered notice that frames one message and an optional action.
    # Reaches for the semantic-role tokens, so every theme styles it
    # without per-instance CSS.
    #
    # @example Basic usage
    #   render MyApp::Callout::Component.new(variant: :info) { "Saved." }
    class Component < Poetry::Core::Component
      requires_content "the message body"

      VARIANTS = %i[info success warning danger].freeze

      AGENT_RULES = [
        "Use Callout for inline notices - never a hand-styled div.",
        "Pick the variant by intent; danger is reserved for destructive outcomes."
      ].freeze

      renders_one :action

      use_stimulus do
        controller :callout do
          target :dismiss
        end
      end

      style :variant, default: :info, required: true, variants: VARIANTS

      option :dismissible, :boolean, default: false

      validates :variant, inclusion: { in: VARIANTS }

      part "root", "The bordered container - variant state rides here",
           states: { "data-variant" => { condition: "always", values: VARIANTS.map(&:to_s) } }
      part "action", "Wrapper around the action slot"

      def initialize(...)
        super
      end

      def before_render
        ensure_content!
      end

      def dismiss_label
        t(".dismiss")
      end

      private

      def css
        # section-level styles resolved by the style DSL
      end
    end
  end
end
```

A component may not need every section - Button has no `use_stimulus`,
static components have no validations. Skip absent sections entirely;
never leave placeholder comments for them. The sections that are
present appear in this order.
