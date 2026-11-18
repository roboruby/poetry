# frozen_string_literal: true

# poetry-motion's importmap pins. The entry, the policy, the engine loader,
# every controller and every behavior preload, as poetry-core's tree does:
# the entry imports the controllers statically and registers them at once,
# so the graph arrives with the page. Only the engine and the kernels are
# pinned without preload; they are fetched by loadEngine(), loadConfetti()
# and loadGlobe() the first time an effect needs them. Bundler hosts use
# the @poetry/motion npm package, where the same dynamic imports split
# them out.
#
# Pins are explicit because a pin_all_from directory overrides any pin of
# the same name; the engine test proves every shipped file has one.

motion = Poetry::Core.javascript_path(File.expand_path("..", __dir__)).join("poetry/motion")

pin "@poetry/motion", to: "poetry/motion/index.js"
pin "@poetry/motion/policy", to: "poetry/motion/policy.js"
pin "@poetry/motion/load_engine", to: "poetry/motion/load_engine.js"
Dir.glob("*_controller.js", base: motion).each do |file|
  pin "@poetry/motion/#{file.delete_suffix(".js")}", to: "poetry/motion/#{file}"
end
pin_all_from File.join(motion, "behaviors"), under: "@poetry/motion/behaviors", to: "poetry/motion/behaviors"
pin "@poetry/motion/engine", to: "poetry/motion-kernel/engine.js", preload: false
pin "@poetry/motion/confetti", to: "poetry/motion-kernel/confetti.js", preload: false
pin "@poetry/motion/globe", to: "poetry/motion-kernel/globe.js", preload: false
