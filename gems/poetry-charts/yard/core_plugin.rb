# frozen_string_literal: true

# Loads poetry-core's YARD extensions (option/style/slot/part handlers) when
# a core checkout is at hand: the Bundler path source, or the sibling
# directory. A released gem ships no yard/ directory, so on CI the registry
# builds without the DSL handlers and the yard gates run on the plain Ruby
# surface; the sibling checkout is where the DSL-projected surface is
# verified. Loaded from .yardopts via --load, never at runtime.

candidates = []
spec = Gem.loaded_specs["poetry-core"]
candidates << File.join(spec.full_gem_path, "yard", "poetry_yard.rb") if spec
candidates << File.expand_path("../../poetry-core/yard/poetry_yard.rb", __dir__)
plugin = candidates.find { |path| File.exist?(path) }
load plugin if plugin
