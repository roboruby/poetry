# poetry motion effects

Contracts generated from the poetry-motion registry. Every effect renders
its finished state on the server; motion is enhancement, and reduced
motion leaves the finished state in place. No spring, pointer input,
scroll link or interruption means a CSS keyframe, not an effect.

## marquee (`poetry_marquee`)

Items that scroll in a loop, logos or testimonials, with a pause control; the loop is CSS.

Class: Poetry::Motion::Marquee::Component - BEM block `poetry-motion-marquee`.
Content block REQUIRED (the items that scroll) - a blockless call raises.
- `animate:` (boolean) - default true - Turns the motion off; the effect renders its finished state either way.
- `direction:` (symbol) - one of left|right|up|down, default "left" - Which way the items travel: left, right, up or down.
- `duration:` (integer) - default 40 - Seconds for one full loop.
- `label:` (string) - The region's accessible name, such as "Our customers".
- `pausable:` (boolean) - default true - Renders the pause control; required for a loop longer than five seconds.
- `pause_label:` (string) - default "Pause" - The pause control's text.
- `repeat:` (integer) - default 2 - How many copies make the loop, the readable one included.
- PART `marquee` - The looping region - pauses on hover, on focus inside, and while data-paused is set | states: data-direction=left|right|up|down (always - the travel direction); data-paused (the pause control holds the loop still) | vars: --marquee-duration (seconds per loop (duration:)); --marquee-gap (the space between items and between copies)
- PART `marquee-viewport` - The clipped window the copies travel through
- PART `marquee-track` - One copy of the items; every copy after the first is aria-hidden and inert
- PART `marquee-pause` - The pause control, a toggle button (aria-pressed) under the loop
- WIRING root: `poetry--motion--marquee` registers
- WIRING pause: `poetry--motion--marquee` actions toggle on click; targets pause
- RULE: Marquee items carry no ids and no focusable controls the reader needs: the loop copies them (aria-hidden and inert), and the readable first copy is what assistive tech gets.
- RULE: Keep pausable: true. A loop that moves for more than five seconds needs a pause control (WCAG 2.2.2); poetry check flags pausable: false.

## number_ticker (`poetry_number_ticker`)

A number that counts up to its server-rendered value when it comes into view.

Class: Poetry::Motion::NumberTicker::Component - BEM block `poetry-motion-number_ticker`.
- `animate:` (boolean) - default true - Turns the motion off; the effect renders its finished state either way.
- `delay:` (integer) - default 0 - Milliseconds to wait before the motion starts.
- `format:` () - Intl.NumberFormat options, camelCase keys (style, currency, minimumFractionDigits, maximumFractionDigits, notation).
- `from:` (float) - default 0 - Where the count starts.
- `locale:` (string) - The locale the number is formatted for; the request's when blank.
- `spring:` (symbol) - one of gentle|snappy|bouncy, default "gentle" - The spring token: gentle, snappy, bouncy.
- `trigger:` (symbol) - one of load|in_view, default "in_view" - When the motion starts: load, in_view.
- `value:` (float) - required - The final number.
- PART `number-ticker` - The number; the count runs in the aria-hidden display
- PART `number-ticker-display` - The visible digits, counted up by the controller and restored to the server's text when the count lands
- WIRING root: `poetry--motion--number-ticker` registers; values value, from, locale (if), format (if), spring, trigger, delay (if), animate (unless animate)
- WIRING display: `poetry--motion--number-ticker` targets display
- BEHAVIOR animate (activated by its JS) - One engine animation toward the element's server-rendered style; skipped under reduced motion and on return visits.
- BEHAVIOR spring (activated by its JS) - A value that springs to each new target and is retargeted without a jump.
- RULE: Effects are decoration; the server-rendered content stands alone and reads right with motion off.
- RULE: No spring, pointer input, scroll link or interruption means a CSS keyframe, not poetry-motion.
- RULE: Animate toward the server-rendered state: the last keyframe is the element's own style.
- RULE: The value is the real number, rendered by the server; never put a placeholder there and let the count fill it in.
- RULE: format: takes Intl.NumberFormat options (style, currency, minimumFractionDigits, ...); the server formats the same number the browser counts to.

## text_reveal (`poetry_text_reveal`)

A short passage whose words brighten one after another as it scrolls into view.

Class: Poetry::Motion::TextReveal::Component - BEM block `poetry-motion-text_reveal`.
- `animate:` (boolean) - default true - Turns the motion off; the effect renders its finished state either way.
- `tag:` (symbol) - one of p|h1|h2|h3|h4|blockquote|div, default "p" - The element the passage renders as.
- `text:` (string) - required - The passage, plain text.
- PART `text-reveal` - The passage; --reveal-progress (0 to 1) brightens its words | vars: --reveal-progress (how far the reveal has come, 1 when finished); --reveal-count (how many words the passage has)
- PART `text-reveal-word` - One word, aria-hidden; its opacity follows the progress | vars: --word-index (the word's position)
- WIRING root: `poetry--motion--text-reveal` (if animate) registers
- BEHAVIOR scroll_value (activated by its JS) - Progress from 0 to 1 tied to scrolling; the finished state under reduced motion.
- RULE: Text reveal is for a short passage of plain text (a statement, a quote), never body copy, links or form labels: the words are rebuilt as spans.
- RULE: Words not yet revealed are dimmed below text contrast on purpose; readers get the whole passage from its hidden copy, and nothing the page needs may live only in a reveal.

## tilt_card (`poetry_tilt_card`)

A surface that leans toward a fine pointer and springs back flat.

Class: Poetry::Motion::TiltCard::Component - BEM block `poetry-motion-tilt_card`.
Content block REQUIRED (the surface that tilts, a card most often) - a blockless call raises.
- `animate:` (boolean) - default true - Turns the motion off; the effect renders its finished state either way.
- `max:` (integer) - default 8 - The largest lean, in degrees.
- `spring:` (symbol) - one of gentle|snappy|bouncy, default "snappy" - The spring token: gentle, snappy, bouncy.
- PART `tilt-card` - The perspective wrapper; never transformed itself
- PART `tilt-card-layer` - The layer that leans | vars: --tilt-x (the lean around the vertical axis, in degrees); --tilt-y (the lean around the horizontal axis, in degrees)
- WIRING root: `poetry--motion--tilt-card` registers; values max, spring, animate (unless animate)
- WIRING layer: `poetry--motion--tilt-card` targets layer
- BEHAVIOR pointer (activated by its JS) - The pointer's position over the element, once a frame; fine pointers only, inert under reduced motion.
- BEHAVIOR spring (activated by its JS) - A value that springs to each new target and is retargeted without a jump.
- RULE: Pointer effects never move focus and never carry information a keyboard user would miss.
- RULE: Never put a popover, menu, select, combobox, tooltip or hover card trigger inside a tilt card: the tilted layer becomes the containing block for their fixed-position panels. poetry check flags it.
- RULE: The lean is decoration: nothing on the card may depend on it, and the card reads the same flat.

