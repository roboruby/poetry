# Changelog

## [0.1.14]

- The released gem serves its JavaScript minified, as poetry-core does, from `dist/javascript` with a source map beside each file. The vendored kernels ship as they were built.

- Six more effects. Layout: `poetry_animated_list` (Turbo Stream changes run as layout transitions), `poetry_layout_group` (elements sharing a `data-layout-id` move between places, the active-tab indicator pattern) and `poetry_shared_element` (a morph across a Turbo visit). Pointer: `poetry_spotlight_card`, `poetry_magnetic` and `poetry_dock`.

- Three text effects: `poetry_typewriter`, `poetry_scramble` and `poetry_word_rotate`. Each renders the finished text for readers and the eye and animates an aria-hidden copy; the word rotate pauses on hover and focus and stops after its rounds on the first word.

- `poetry_background`: a decorative background in CSS alone, a grid or dot pattern with an aurora, meteors, a retro grid or ripples, faded at the edges. No script; every layer is aria-hidden and placed deterministically, and reduced motion stills the effect.

- Two scroll effects: `poetry_scroll_progress`, a reading bar for the page or one long element that keeps following under reduced motion since it is feedback on the reader's own scrolling, and `poetry_parallax`, content that drifts at its own pace and rests where the server put it under reduced motion. `useScrollValue` takes `follow: true` for scroll feedback.

- Three canvas effects: `poetry_particles` (drifting, optionally linked dots drawn by the canvas pattern, seeded so a still frame is the same every visit), `poetry_confetti` (a burst from a click, or once on render, on a server-rendered full-viewport canvas) and `poetry_globe` (a dotted, turning globe with markers). Confetti and the globe each load their own vendored kernel on demand: canvas-confetti 1.9.4 (ISC) and cobe 2.0.1 (MIT), recorded in THIRD_PARTY_NOTICES.

- Two drag effects: `poetry_draggable` (content you can pick up, bounded to its parent if you like, springing home or staying where dropped) and `poetry_swipe_cards` (a labelled, focusable stack: drag the top card past the threshold, press the arrow keys, or use the `with_actions` buttons; each swipe dispatches `poetry--motion--swipe-cards:swipe`). `useDrag` measures function bounds per drag and survives a lost pointer capture.

### Changed

- The effect controllers register eagerly, as poetry-core's do: `registerPoetryMotionControllers` imports all nineteen (about 6 KB gzipped together) and registers them at once. A lazily imported controller lost the presses that dispatched while its module was in flight (five of eight first clicks on the marquee's pause and the confetti over a slow connection, measured on the docs host); the engine and the kernels still load on demand.
- An animation that finishes on its own now leaves the element its own style, as a teardown does; springs keep their value until teardown.
- Reduced motion stills page and layout view transitions too.
- The gentle and snappy spring tokens are critically damped (120 22 1 and 400 40 1), so they settle without passing their target; bouncy keeps its bounce.

### Added

- The first four effects, each rendering its finished state on the server: `poetry_marquee` (a CSS loop with one readable copy, inert copies and a pause control), `poetry_text_reveal` (words brighten as the passage scrolls in), `poetry_number_ticker` (springs up to a server-rendered, formatted number) and `poetry_tilt_card` (a layer that leans toward a fine pointer). `motion_options` gives an effect `animate:` and the token-validated motion options it takes. The gem ships its registry, controllers manifest, previews, axe and visual baselines.
- The gem: a Rails engine with importmap pins, the vendored motion 14.1.0 engine loaded on demand through `loadEngine()`, the motion policy (reduced motion, tokens, the Turbo cache flush, the view-transition slot), the motion tokens stylesheet, and the `Poetry::Motion::Behaviors` namespace for behaviors. No effects yet.
- Ten behaviors over the per-connect scope, each undone by `teardown(this)`: `useAnimate`, `useSpring`, `useStagger`, `useScrollValue`, `usePointer`, `useFrame`, `useLayout`, `useDrag`, `useGesture` and `useCanvas`, imported from `@poetry/motion/behaviors/<name>`. Each follows the motion policy: reduced motion leaves elements at their own style (drag still drags, without the spring back), entrances skip cache previews and restore visits, and a running animation ends at its finished state when reduced motion turns on. Each has a Ruby declaration, `Poetry::Motion::Behaviors::<Name>`, that an effect uses with `use_behavior`, so the registry, llms.txt and the docs list it; `animate` carries the agent rules that effects are decoration, that motion without a spring, pointer, scroll link or interruption is a CSS keyframe, and that animations end at the server-rendered style.
