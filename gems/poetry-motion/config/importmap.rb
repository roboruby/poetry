# frozen_string_literal: true

# poetry-motion's importmap pins. Three small modules preload: the entry,
# which registers controllers lazily, the motion policy and the engine
# loader. Everything an effect needs loads when the effect first appears:
# each controller and every behavior is pinned with preload: false, and
# the engine is fetched only by loadEngine(). Bundler hosts use the
# @poetry/motion npm package, where the same dynamic imports split it out.
#
# Pins are explicit because a pin_all_from directory overrides any pin of
# the same name; the engine test proves every shipped file has one.

motion = Poetry::Core.javascript_path(File.expand_path("..", __dir__)).join("poetry/motion")

pin "@poetry/motion", to: "poetry/motion/index.js"
pin "@poetry/motion/policy", to: "poetry/motion/policy.js"
pin "@poetry/motion/load_engine", to: "poetry/motion/load_engine.js"
Dir.glob("*_controller.js", base: motion).each do |file|
  pin "@poetry/motion/#{file.delete_suffix(".js")}", to: "poetry/motion/#{file}", preload: false
end
pin_all_from File.join(motion, "behaviors"), under: "@poetry/motion/behaviors", to: "poetry/motion/behaviors",
                                             preload: false
pin "@poetry/motion/engine", to: "poetry/motion-kernel/engine.js", preload: false
pin "@poetry/motion/confetti", to: "poetry/motion-kernel/confetti.js", preload: false
pin "@poetry/motion/globe", to: "poetry/motion-kernel/globe.js", preload: false
