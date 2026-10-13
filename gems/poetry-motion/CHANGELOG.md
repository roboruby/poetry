# Changelog

## [0.1.14]

### Added

- The gem: a Rails engine with importmap pins, the vendored motion 14.1.0 engine loaded on demand through `loadEngine()`, the motion policy (reduced motion, tokens, the Turbo cache flush, the view-transition slot), the motion tokens stylesheet, and the `Poetry::Motion::Behaviors` namespace for behaviors. No effects yet.
- Ten behaviors over the per-connect scope, each undone by `teardown(this)`: `useAnimate`, `useSpring`, `useStagger`, `useScrollValue`, `usePointer`, `useFrame`, `useLayout`, `useDrag`, `useGesture` and `useCanvas`, imported from `@poetry/motion/behaviors/<name>`. Each follows the motion policy: reduced motion leaves elements at their own style (drag still drags, without the spring back), entrances skip cache previews and restore visits, and a running animation ends at its finished state when reduced motion turns on. Each has a Ruby declaration, `Poetry::Motion::Behaviors::<Name>`, that an effect uses with `use_behavior`, so the registry, llms.txt and the docs list it; `animate` carries the agent rules that effects are decoration, that motion without a spring, pointer, scroll link or interruption is a CSS keyframe, and that animations end at the server-rendered style.
