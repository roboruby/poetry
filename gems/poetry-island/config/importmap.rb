# frozen_string_literal: true

# poetry-island's importmap pins: the entry, which registers the island
# controller, and the controller itself. Both preload; together they are a
# few kilobytes, and every island module loads on its own, through the
# host's pin for it, the first time its island connects.
pin "@poetry/island", to: "poetry/island/index.js"
pin "@poetry/island/island_controller", to: "poetry/island/island_controller.js"
