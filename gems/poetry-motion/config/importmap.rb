# frozen_string_literal: true

# poetry-motion's importmap pins. The controllers, behaviors and policy
# preload like any pin. The engine does NOT: it lives outside the pinned
# tree and is pinned with preload: false, so a page fetches it only when a
# behavior first calls loadEngine(). Bundler hosts use the @poetry/motion
# npm package, where the same dynamic import splits it out.

pin "@poetry/motion", to: "poetry/motion/index.js"
pin_all_from File.expand_path("../app/javascript/poetry/motion", __dir__),
             under: "@poetry/motion", to: "poetry/motion"
pin "@poetry/motion/engine", to: "poetry/motion-kernel/engine.js", preload: false
