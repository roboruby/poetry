# frozen_string_literal: true

require "digest"
require "json"

module Poetry
  module Core
    # Turns remote registry addresses into a deterministic install PLAN:
    # resolve the dependency tree (visited-set walk,
    # then Kahn topo-sort so dependencies write before dependents), classify
    # every dependency (poetry gem components satisfy at RUNTIME - no copy;
    # gem blocks copy in through their own generator; everything else
    # fetches recursively via the sibling convention), validate every write
    # target against a traversal-safe allowlist, and collect the report-only
    # side effects (Gemfile additions are PRINTED, never executed - no
    # lifecycle scripts, ever; the shadcn trust gap poetry does not copy).
    # The add generator executes the plan with its idempotent primitives;
    # this class never touches the filesystem it plans for.
    class RegistryInstaller
      class Error < Poetry::Core::Error; end

      ALLOWED_TARGET_ROOTS = %w[app/components app/views app/javascript app/helpers app/assets].freeze
      COMMUNITY_CSS_DIR = "app/assets/tailwind/poetry/community"

      Plan = Struct.new(:writes, :css_writes, :entry_lines, :gem_satisfied, :block_installs,
                        :gem_deps, :docs, :manifest, keyword_init: true)
      Write = Struct.new(:target, :content, :item, keyword_init: true)

      # @param client [RegistryClient] resolves remote addresses to items
      # @param local_components [Enumerable<String>] kebab names the
      #   installed poetry gems provide at runtime (no copy needed)
      # @param local_blocks [Enumerable<String>] kebab names of the gem's
      #   copy-in blocks (installed via their own generator)
      # @param destination_root [String] the host app root targets must stay
      #   inside
      # @param loaded_gems [Enumerable<String>] present gems, for the
      #   report-only dependency check
      def initialize(client:, destination_root:, local_components: [], local_blocks: [],
                     loaded_gems: Gem.loaded_specs.keys)
        @client = client
        @local_components = local_components.to_set { |name| name.tr("_", "-") }
        @local_blocks = local_blocks.to_set { |name| name.tr("_", "-") }
        @destination_root = destination_root
        @loaded_gems = loaded_gems.to_set
      end

      # @param addresses [Array<RegistryAddress>] remote addresses only
      # @return [Plan]
      def plan(addresses)
        state = { items: {}, edges: Hash.new { |hash, key| hash[key] = [] },
                  resolved: {}, sources: {}, gem_satisfied: [], block_installs: [] }
        addresses.each { |address| resolve_into(state, address) }
        build_plan(state)
      end

      private

      def resolve_into(state, address)
        return state[:resolved][address.raw] if state[:resolved].key?(address.raw)

        item = @client.resolve(address)
        name = item["name"]
        state[:resolved][address.raw] = name
        register_item(state, name, item, address)
        (item["registryDependencies"] || []).each do |dep|
          dep_name = resolve_dependency(state, address, dep)
          state[:edges][name] << dep_name if dep_name
        end
        name
      end

      # Two addresses may legitimately land on the same item (diamond deps);
      # the same NAME with different content is a collision, not a merge.
      def register_item(state, name, item, address)
        if (existing = state[:items][name])
          return if item_digest(existing) == item_digest(item)

          raise Error, "#{address.raw} and #{state[:sources][name]} both provide #{name.inspect} " \
                       "with different content - refusing to pick one"
        end
        state[:items][name] = item
        state[:sources][name] = address.raw
      end

      def item_digest(item)
        Digest::SHA256.hexdigest(JSON.generate(item))
      end

      # @return [String, nil] the remote item name this dependency resolves
      #   to, or nil when the installed gems satisfy it (recorded on state).
      def resolve_dependency(state, parent, dep)
        dep_address = RegistryAddress.parse(dep)
        return resolve_into(state, dep_address) unless local_candidate?(dep_address)

        kebab = dep_address.name
        if @local_components.include?(kebab)
          state[:gem_satisfied] |= [kebab]
          nil
        elsif @local_blocks.include?(kebab)
          state[:block_installs] |= [kebab]
          nil
        elsif dep_address.kind == :bare
          resolve_into(state, parent.sibling(kebab))
        else
          raise Error, "#{dep} is not provided by the installed poetry gems"
        end
      end

      # Bare names and @poetry/* check the installed gems first - the poetry
      # twist on shadcn's DAG: core components are runtime-provided, so a
      # community item that composes Button needs no Button copy.
      def local_candidate?(address)
        address.kind == :bare || (address.kind == :namespace && address.namespace == "@poetry")
      end

      def build_plan(state)
        order = topo_order(state)
        items = order.map { |name| state[:items][name] }
        Plan.new(
          writes: collect_writes(state, order),
          css_writes: items.filter_map { |item| css_write(item) },
          entry_lines: items.filter_map { |item| entry_line(item) },
          gem_satisfied: state[:gem_satisfied].sort,
          block_installs: state[:block_installs].sort,
          gem_deps: missing_gem_deps(items),
          docs: items.filter_map { |item| item["docs"] },
          manifest: order.to_h { |name| [name, { "source" => state[:sources][name] }] }
        )
      end

      # Kahn: an item writes only after every remote item it depends on has
      # written. Deterministic (sorted ready set); leftovers = a cycle.
      def topo_order(state)
        remaining = state[:items].keys.sort
        deps = remaining.to_h { |name| [name, state[:edges][name] & remaining] }
        order = []
        until remaining.empty?
          ready = remaining.select { |name| (deps[name] - order).empty? }.sort
          raise Error, "registry dependency cycle among: #{remaining.join(", ")}" if ready.empty?

          order.concat(ready)
          remaining -= ready
        end
        order
      end

      def collect_writes(state, order)
        seen = {}
        order.flat_map do |name|
          state[:items][name].fetch("files", []).filter_map do |file|
            target = file["target"] || file["path"]
            validate_target!(target, item: name)
            deduplicate_write(seen, target, file["content"], name)
          end
        end
      end

      def deduplicate_write(seen, target, content, name)
        digest = Digest::SHA256.hexdigest(content)
        if (previous = seen[target])
          return nil if previous[:digest] == digest

          raise Error, "#{name} and #{previous[:name]} both write #{target} with different content"
        end
        seen[target] = { digest: digest, name: name }
        Write.new(target: target, content: content, item: name)
      end

      # Traversal defense: relative, inside the allowlisted app roots, and -
      # belt and braces - expanding inside destination_root.
      def validate_target!(target, item:)
        offense =
          if target.start_with?("/", "~") || target.match?(/\A[A-Za-z]:/) then "an absolute path"
          elsif target.include?("..") then "path traversal"
          elsif target.include?("\0") || target.include?("\\") then "an illegal character"
          elsif ALLOWED_TARGET_ROOTS.none? { |root| target.start_with?("#{root}/") }
            "outside the allowed roots (#{ALLOWED_TARGET_ROOTS.join(", ")})"
          end
        raise Error, "#{item}: refusing target #{target.inspect} - #{offense}" if offense

        expanded = File.expand_path(target, @destination_root)
        return if expanded.start_with?(File.expand_path(@destination_root) + File::SEPARATOR)

        raise Error, "#{item}: refusing target #{target.inspect} - escapes the app root"
      end

      def css_write(item)
        content = css_content(item)
        return nil unless content

        { path: "#{COMMUNITY_CSS_DIR}/#{item["name"]}.css", content: content }
      end

      def entry_line(item)
        return nil unless css_content(item)

        %(@import "./poetry/community/#{item["name"]}.css";)
      end

      # cssVars follow shadcn's three sections (theme/light/dark); css
      # passes through verbatim. One file per item, imported from the host's
      # Tailwind entry like every other poetry fragment.
      def css_content(item)
        vars = item["cssVars"] || {}
        sections = [
          css_block("@theme", vars["theme"]),
          css_block(":root", vars["light"]),
          css_block(".dark", vars["dark"]),
          item["css"].is_a?(String) && !item["css"].empty? ? item["css"] : nil
        ].compact
        return nil if sections.empty?

        "/* #{item["name"]} - installed by bin/rails g poetry:add */\n#{sections.join("\n\n")}\n"
      end

      def css_block(selector, vars)
        return nil unless vars.is_a?(Hash) && vars.any?

        lines = vars.map { |key, value| "  --#{key.to_s.delete_prefix("--")}: #{value};" }
        "#{selector} {\n#{lines.join("\n")}\n}"
      end

      # Report-only, never executed: which declared gem dependencies the
      # bundle is missing. "name" or "name@constraint" forms accepted.
      def missing_gem_deps(items)
        items.flat_map { |item| item["dependencies"] || [] }.uniq.reject do |dep|
          @loaded_gems.include?(dep.split("@").first)
        end
      end
    end
  end
end
