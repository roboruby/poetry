# frozen_string_literal: true

# poetry-core's importmap pins (the importmap-first channel): the
# host app's importmap merges these, so `import { registerPoetryControllers }
# from "@poetry/controllers"` works with zero build. Subpath specifiers
# (@poetry/controllers/helpers/state) resolve here via pin_all_from and in
# bundler hosts via the npm package's exports map - one source, two channels.

pin "@poetry/controllers", to: "poetry/core/index.js"
pin_all_from Poetry::Core.javascript_path(File.expand_path("..", __dir__)).join("poetry/core"),
             under: "@poetry/controllers", to: "poetry/core"
