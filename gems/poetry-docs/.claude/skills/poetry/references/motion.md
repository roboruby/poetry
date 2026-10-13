# poetry motion effects

Contracts generated from the poetry-motion registry. Every effect renders
its finished state on the server; motion is enhancement, and reduced
motion leaves the finished state in place. No spring, pointer input,
scroll link or interruption means a CSS keyframe, not an effect.

## animated_list (`poetry_animated_list`)

A list whose Turbo Stream changes animate: new items fade in, removed ones fade out, the rest slide into place.

Class: Poetry::Motion::AnimatedList::Component - BEM block `poetry-motion-animated_list`.
Content block REQUIRED (the list's items) - a blockless call raises.
- `animate:` (boolean) - default true - Turns the motion off; the effect renders its finished state either way.
- `as:` (symbol) - one of ul|ol|div, default "ul" - The element the list renders as: ul, ol or div.
- `duration:` () - default "normal" - How long the motion runs: a duration token (fast, normal, slow) or milliseconds.
- PART `animated-list` - The list; its direct children are the items that enter, leave and move | states: data-animated-list (always - the list's own key, which names its items in the transition)
- WIRING root: `poetry--motion--animated-list` (if animate) registers; values duration
- BEHAVIOR layout (activated by its JS) - DOM changes animated as layout transitions, only when no Turbo visit holds the view-transition slot.
- RULE: Give the list an id: and target it (or its items) with Turbo Streams; the streams animate, the server-rendered list is the finished state.
- RULE: Each direct child is one item. Keep item elements stable across renders so survivors slide instead of fading out and back in.

## background (`poetry_background`)

A decorative background in CSS alone: a grid or dot pattern, with aurora, meteors, a retro grid or ripples.

Class: Poetry::Motion::Background::Component - BEM block `poetry-motion-background`.
- `animate:` (boolean) - default true - Turns the motion off; the effect renders its finished state either way.
- `count:` (integer) - default 12 - How many meteors or rings the effect draws.
- `effect:` (symbol) - one of none|aurora|meteors|retro_grid|ripple, default "none" - The effect: none, aurora, meteors, retro_grid or ripple.
- `fade:` (symbol) - one of none|radial|bottom, default "radial" - How the decoration fades: none, radial or bottom.
- `pattern:` (symbol) - one of none|grid|dots, default "grid" - The pattern: none, grid or dots.
- PART `background` - The region; the decoration sits behind its content | states: data-pattern=none|grid|dots (always - the pattern); data-effect=none|aurora|meteors|retro_grid|ripple (always - the effect); data-fade=none|radial|bottom (always - the edge fade); data-animate (present as false when the effect is still (animate: false))
- PART `background-layer` - The decoration behind the content, aria-hidden
- PART `background-particle` - One meteor or ring of the effect | vars: --particle-index (its place among the effect's particles); --particle-x (its horizontal start, in percent); --particle-delay (its delay, in seconds)
- RULE: Backgrounds are decoration: text on them still meets contrast, and the content stands on its own with the background removed.
- RULE: This is the CSS tier: a background that follows the pointer, draws on a canvas or runs a shader is not this component.

## confetti (`poetry_confetti`)

A burst of confetti over the page from a click, or once when a success message renders.

Class: Poetry::Motion::Confetti::Component - BEM block `poetry-motion-confetti`.
- `animate:` (boolean) - default true - Turns the motion off; the effect renders its finished state either way.
- `count:` (integer) - default 120 - How many pieces per burst.
- `spread:` (integer) - default 70 - The burst's spread, in degrees.
- `trigger:` (symbol) - one of click|load, default "click" - When the motion starts: click, load.
- PART `confetti` - The control the burst comes from, or the moment it marks
- PART `confetti-canvas` - The full-viewport, aria-hidden canvas the pieces fly on
- WIRING root: `poetry--motion--confetti` (if animate) registers; values trigger, count, spread
- WIRING canvas: `poetry--motion--confetti` (if animate) targets canvas
- BEHAVIOR canvas (activated by its JS) - A canvas sized to its box at the pixel ratio, drawn every visible frame; one static frame under reduced motion.
- RULE: Confetti celebrates a moment the user caused - a finished task, a purchase. It never carries the message: say what happened in text, and let the confetti decorate it.

## dock (`poetry_dock`)

A row of links or buttons that swell toward the pointer, the nearest most, like a launcher.

Class: Poetry::Motion::Dock::Component - BEM block `poetry-motion-dock`.
Content block REQUIRED (the items, each a direct child) - a blockless call raises.
- `animate:` (boolean) - default true - Turns the motion off; the effect renders its finished state either way.
- `distance:` (integer) - default 120 - How far, in pixels, the swell reaches from the pointer.
- `label:` (string) - The navigation's accessible name.
- `magnification:` (float) - default 1.5 - The scale of the item right under the pointer.
- `orientation:` (symbol) - one of horizontal|vertical, default "horizontal" - Which way the dock runs.
- `spring:` (symbol) - one of gentle|snappy|bouncy, default "snappy" - The spring token: gentle, snappy, bouncy.
- PART `dock` - The row of items; the swell reaches across it | states: data-orientation=horizontal|vertical (always - which way the dock runs)
- WIRING root: `poetry--motion--dock` (if animate) registers; values magnification, distance, spring
- BEHAVIOR pointer (activated by its JS) - The pointer's position over the element, once a frame; fine pointers only, inert under reduced motion.
- BEHAVIOR spring (activated by its JS) - A value that springs to each new target and is retargeted without a jump.
- RULE: Pointer effects never move focus and never carry information a keyboard user would miss.
- RULE: Each item is a real link or button with an accessible name; the swell is decoration and the dock works the same without it.
- RULE: Leave room around the dock for the swell: items scale past their box without moving others.

## globe (`poetry_globe`)

A dotted, slowly turning globe with markers at the places you give it.

Class: Poetry::Motion::Globe::Component - BEM block `poetry-motion-globe`.
- `animate:` (boolean) - default true - Turns the motion off; the effect renders its finished state either way.
- `label:` (string) - What the globe shows, for a screen reader.
- `markers:` () - default [] - [[latitude, longitude], ...]
- `speed:` (float) - default 0.3 - Radians per second it turns; 0 holds it still.
- PART `globe` - The square the globe fills
- PART `globe-canvas` - The canvas cobe draws on
- WIRING root: `poetry--motion--globe` (if animate) registers; values markers (if), speed
- WIRING canvas: `poetry--motion--globe` (if animate) targets canvas
- BEHAVIOR frame (activated by its JS) - A callback every frame, paused off screen and in hidden tabs; never runs under reduced motion.
- RULE: The globe is a picture: give it label: or put the places in text beside it; the markers are not readable on their own.

## layout_group (`poetry_layout_group`)

Elements that share a data-layout-id move as one thing between places, like an active-tab indicator.

Class: Poetry::Motion::LayoutGroup::Component - BEM block `poetry-motion-layout_group`.
Content block REQUIRED (the elements that carry data-layout-id) - a blockless call raises.
- `animate:` (boolean) - default true - Turns the motion off; the effect renders its finished state either way.
- `duration:` () - default "normal" - How long the motion runs: a duration token (fast, normal, slow) or milliseconds.
- PART `layout-group` - The region whose data-layout-id elements move between places
- PART `layout-group-item` - One place a moving element can be; the visible one is current | states: data-layout-id (always - the id every place of one moving element shares)
- WIRING root: `poetry--motion--layout-group` (if animate) registers; values duration
- BEHAVIOR animate (activated by its JS) - One engine animation toward the element's server-rendered style; skipped under reduced motion and on return visits.
- RULE: Effects are decoration; the server-rendered content stands alone and reads right with motion off.
- RULE: No spring, pointer input, scroll link or interruption means a CSS keyframe, not poetry-motion.
- RULE: Animate toward the server-rendered state: the last keyframe is the element's own style.
- RULE: Show exactly one element per data-layout-id at a time; the group animates the newly visible one from the old one's box. Hide the others with display, never visibility or opacity.

## magnetic (`poetry_magnetic`)

A wrapper that pulls its control a few pixels toward the pointer and springs it home.

Class: Poetry::Motion::Magnetic::Component - BEM block `poetry-motion-magnetic`.
Content block REQUIRED (the control the pointer pulls) - a blockless call raises.
- `animate:` (boolean) - default true - Turns the motion off; the effect renders its finished state either way.
- `spring:` (symbol) - one of gentle|snappy|bouncy, default "snappy" - The spring token: gentle, snappy, bouncy.
- `strength:` (integer) - default 8 - The farthest the content moves, in pixels.
- PART `magnetic` - The wrapper that catches the pointer; never moves itself
- PART `magnetic-layer` - The layer that moves | vars: --magnet-x (the pull along x, in pixels); --magnet-y (the pull along y, in pixels)
- WIRING root: `poetry--motion--magnetic` (if animate) registers; values strength, spring
- WIRING layer: `poetry--motion--magnetic` (if animate) targets layer
- BEHAVIOR pointer (activated by its JS) - The pointer's position over the element, once a frame; fine pointers only, inert under reduced motion.
- BEHAVIOR spring (activated by its JS) - A value that springs to each new target and is retargeted without a jump.
- RULE: Pointer effects never move focus and never carry information a keyboard user would miss.
- RULE: Wrap one control, a call to action; a page of magnetic controls is noise. The pull is decoration and never the only cue that something is interactive.

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

## parallax (`poetry_parallax`)

Content that drifts at its own pace as it scrolls through the viewport.

Class: Poetry::Motion::Parallax::Component - BEM block `poetry-motion-parallax`.
Content block REQUIRED (the content that drifts) - a blockless call raises.
- `animate:` (boolean) - default true - Turns the motion off; the effect renders its finished state either way.
- `distance:` (integer) - default 80 - Pixels of drift from entering the viewport to leaving it; negative drifts the other way.
- PART `parallax` - The drifting content | vars: --parallax-y (the current drift, in pixels; 0 when centered)
- WIRING root: `poetry--motion--parallax` (if animate) registers; values distance
- BEHAVIOR scroll_value (activated by its JS) - Progress from 0 to 1 tied to scrolling; the finished state under reduced motion.
- RULE: Parallax is for decoration and imagery, never for text a reader is reading; keep the distance small, and leave room so the drift never clips the content.

## particles (`poetry_particles`)

A field of slow-drifting dots behind the content, optionally linked by faint lines.

Class: Poetry::Motion::Particles::Component - BEM block `poetry-motion-particles`.
- `animate:` (boolean) - default true - Turns the motion off; the effect renders its finished state either way.
- `count:` (integer) - default 60 - How many dots.
- `link:` (integer) - default 0 - Pixels within which two dots are linked by a line; 0 links none.
- `speed:` (integer) - default 12 - Drift speed, in pixels per second.
- PART `particles` - The region; the canvas sits behind its content
- PART `particles-canvas` - The aria-hidden canvas the dots are drawn on
- WIRING root: `poetry--motion--particles` (if animate) registers; values count, speed, link (if)
- WIRING canvas: `poetry--motion--particles` (if animate) targets canvas
- BEHAVIOR canvas (activated by its JS) - A canvas sized to its box at the pixel ratio, drawn every visible frame; one static frame under reduced motion.
- BEHAVIOR frame (activated by its JS) - A callback every frame, paused off screen and in hidden tabs; never runs under reduced motion.
- RULE: Particles are a background: the content stands on its own and keeps its contrast without them.

## scramble (`poetry_scramble`)

Text that decodes from random glyphs into itself when it comes into view.

Class: Poetry::Motion::Scramble::Component - BEM block `poetry-motion-scramble`.
- `animate:` (boolean) - default true - Turns the motion off; the effect renders its finished state either way.
- `delay:` (integer) - default 0 - Milliseconds to wait before the motion starts.
- `duration:` () - default "slow" - How long the motion runs: a duration token (fast, normal, slow) or milliseconds.
- `text:` (string) - required - The text, plain.
- `trigger:` (symbol) - one of load|in_view, default "in_view" - When the motion starts: load, in_view.
- PART `scramble` - The text
- PART `scramble-display` - The aria-hidden copy that scrambles
- WIRING root: `poetry--motion--scramble` (if animate) registers; values duration, delay (if), trigger
- WIRING display: `poetry--motion--scramble` (if animate) targets display
- RULE: Scramble a short label or heading, ideally in a monospace face so the width holds; never text a reader needs mid-animation.

## scroll_progress (`poetry_scroll_progress`)

A thin bar that fills as the reader scrolls the page or one long element.

Class: Poetry::Motion::ScrollProgress::Component - BEM block `poetry-motion-scroll_progress`.
- `position:` (symbol) - one of top|bottom|inline, default "top" - top or bottom pins the bar to the viewport edge; inline leaves it in place.
- `target:` (string) - The id of the element whose scroll the bar follows; the page when blank.
- PART `scroll-progress` - The bar; it fills from the start edge | states: data-position=top|bottom|inline (always - where the bar sits) | vars: --scroll-progress (how far the reader has scrolled, 0 to 1)
- WIRING root: `poetry--motion--scroll-progress` registers; values target_id (if)
- BEHAVIOR scroll_value (activated by its JS) - Progress from 0 to 1 tied to scrolling; the finished state under reduced motion.
- RULE: Use one scroll progress bar per page, for long reading; it is decorative and never the only sign of where the reader is.

## shared_element (`poetry_shared_element`)

An element a Turbo visit morphs from one page to the next, like a card into its detail page.

Class: Poetry::Motion::SharedElement::Component - BEM block `poetry-motion-shared_element`.
Content block REQUIRED (the element both pages share) - a blockless call raises.
- `as:` (symbol) - default "div" - The element it renders as.
- `name:` (string) - required - The view-transition name both pages give the element.
- PART `shared-element` - The element the visit morphs between pages; carries view-transition-name
- RULE: Use one name per element per page: two elements with the same name on one page cancel the transition. Build names from the record, such as product-42.
- RULE: Shared elements need <meta name="view-transition" content="same-origin"> in the layout; without it the visit swaps the page with no morph.

## spotlight_card (`poetry_spotlight_card`)

A surface with a soft glow that follows the pointer across it.

Class: Poetry::Motion::SpotlightCard::Component - BEM block `poetry-motion-spotlight_card`.
Content block REQUIRED (the surface the glow follows the pointer across) - a blockless call raises.
- `animate:` (boolean) - default true - Turns the motion off; the effect renders its finished state either way.
- `size:` (integer) - default 320 - The glow's diameter in pixels.
- PART `spotlight-card` - The surface; ::before draws the glow | vars: --spotlight-x (the pointer's x within the card); --spotlight-y (the pointer's y within the card); --spotlight-opacity (1 while a fine pointer is over the card); --spotlight-size (the glow's diameter (size:))
- WIRING root: `poetry--motion--spotlight-card` (if animate) registers
- BEHAVIOR pointer (activated by its JS) - The pointer's position over the element, once a frame; fine pointers only, inert under reduced motion.
- RULE: Pointer effects never move focus and never carry information a keyboard user would miss.
- RULE: The glow is decoration: the surface reads the same without it, and it never carries state.

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

## typewriter (`poetry_typewriter`)

A line typed out a character at a time when it comes into view.

Class: Poetry::Motion::Typewriter::Component - BEM block `poetry-motion-typewriter`.
- `animate:` (boolean) - default true - Turns the motion off; the effect renders its finished state either way.
- `cursor:` (boolean) - default true - Shows a caret after the text while it types.
- `delay:` (integer) - default 0 - Milliseconds to wait before the motion starts.
- `speed:` (integer) - default 50 - Milliseconds per character.
- `text:` (string) - required - The line, plain text.
- `trigger:` (symbol) - one of load|in_view, default "in_view" - When the motion starts: load, in_view.
- PART `typewriter` - The line; a caret follows the text while it types | states: data-typing (the line is typing); data-cursor (the caret is on (cursor:))
- PART `typewriter-display` - The aria-hidden copy that types
- WIRING root: `poetry--motion--typewriter` (if animate) registers; values speed, delay (if), trigger
- WIRING display: `poetry--motion--typewriter` (if animate) targets display
- RULE: Type one short line, a headline or a prompt; never body copy or anything a reader must wait for. The line is complete in the page before it types.

## word_rotate (`poetry_word_rotate`)

A word that turns over into the next in place, then settles on the first.

Class: Poetry::Motion::WordRotate::Component - BEM block `poetry-motion-word_rotate`.
- `animate:` (boolean) - default true - Turns the motion off; the effect renders its finished state either way.
- `interval:` (integer) - default 2500 - Milliseconds each word shows.
- `rounds:` (integer) - default 1 - How many times it goes through the words; 0 keeps going.
- `words:` (list) - required - The words, the first one first.
- PART `word-rotate` - The cell the words share, sized to the longest
- PART `word-rotate-word` - One word; the active one shows | states: data-active (the word showing)
- WIRING root: `poetry--motion--word-rotate` (if animate) registers; values interval, rounds
- WIRING word: `poetry--motion--word-rotate` (if animate) targets word
- RULE: The first word is the one that counts: it is what renders, what a screen reader hears and where the rotation stops. Order the words so the sentence reads right with only it.
- RULE: Keep rounds: small. A rotation that runs past five seconds is auto-updating content and needs a way to stop it (WCAG 2.2.2); rounds: 0 never stops.

