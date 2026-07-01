# frozen_string_literal: true

require "digest"

module Poetry
  module Core
    module CSS
      # poetry's in-tree server-side CVA engine ( - class_variants
      # absorbed, the external runtime dep dropped).
      #
      # The resolver is a dictionary from a component's style surface to CSS
      # utility classes:
      #
      #   base      "inline-flex items-center"           # the block root
      #   element   :icon, "size-4 shrink-0"             # BEM elements (block__icon)
      #   variant   :color, red: "text-red-600", ...     # BEM modifiers (block--color-red)
      #   compound  ({ color: :red, mode: :dark }, "...") # multi-key combinations
      #
      # Deliberately UNLIKE class_variants, the resolver stores **no
      # defaults**: default values live in exactly one place - the
      # component's `style :attr, default:` declaration (ActiveModel fills
      # them before render) - which structurally kills the vcplus
      # duplicated-defaults bug. Render criteria always arrive resolved.
      #
      # Merging goes through the shared, FIFO-cached Config merger
      # (configured once - never a fresh TailwindMerge instance per render).
      class Resolver
        Compound = Struct.new(:criteria, :classes)

        attr_reader :bases, :elements, :variants, :compounds

        def initialize
          @bases = []
          @elements = {}
          @variants = {}
          @compounds = []
        end

        # Subclass inheritance: a child Style extends a copy of its parent's
        # dictionary (same model as class_variants' dup-on-inherit).
        def dup
          self.class.new.tap do |copy|
            copy.instance_variable_set(:@bases, @bases.dup)
            copy.instance_variable_set(:@elements, @elements.transform_values(&:dup))
            copy.instance_variable_set(:@variants, @variants.transform_values(&:dup))
            copy.instance_variable_set(:@compounds, @compounds.dup)
          end
        end

        # -- The dictionary DSL ------------------------------------------------

        def base(classes)
          @bases << classes.to_s
          self
        end

        def element(name, classes)
          (@elements[name.to_sym] ||= []) << classes.to_s
          self
        end

        def variant(attr, mapping)
          bucket = (@variants[attr.to_sym] ||= {})
          mapping.each { |value, classes| bucket[value] = classes.to_s }
          self
        end

        def compound(criteria, classes)
          raise ArgumentError, "compound criteria must name at least two variant keys" if criteria.size < 2

          @compounds << Compound.new(criteria.transform_keys(&:to_sym), classes.to_s)
          self
        end

        # -- Rendering ---------------------------------------------------------

        # Resolves utility classes for the block root (element: nil) or a
        # named element. `criteria` are the component's resolved style values;
        # `extra` is a caller-supplied class string appended last (wins on
        # Tailwind conflicts via the merger).
        def render(element = nil, extra: nil, **criteria)
          classes = element ? @elements.fetch(element.to_sym, []).dup : root_classes(criteria)
          classes << extra if extra
          merger.merge(*classes)
        end

        # The introspection surface (previews, docs, the registry):
        # { attr => [values] } for the declared variant space.
        def variant_options
          @variants.transform_values(&:keys)
        end

        # The capsule digest (the capsule-digest leak guard): a
        # deterministic content hash of the whole dictionary. Embedded in the
        # generated :bem reference stylesheet, so CSS written against an older
        # dictionary is detectable instead of silently drifting.
        def digest
          Digest::SHA256.hexdigest(canonical_dictionary.inspect)[0, 12]
        end

        # Every utility class string in the dictionary (bases, elements,
        # variants, compounds) - the Verifier's and the safelist's input.
        def all_classes
          [
            @bases,
            @elements.values.flatten,
            @variants.values.flat_map(&:values),
            @compounds.map(&:classes)
          ].flatten.flat_map(&:split).uniq
        end

        private

        # A stable, order-insensitive serialization of the dictionary for the
        # capsule digest.
        def canonical_dictionary
          {
            bases: @bases,
            elements: @elements.sort_by { |name, _| name.to_s }.to_h { |name, v| [name, v] },
            variants: @variants.sort_by { |attr, _| attr.to_s }
                               .map { |attr, mapping| [attr, mapping.sort_by { |value, _| value.to_s }] },
            compounds: @compounds.map { |rule| [rule.criteria.sort_by { |k, _| k.to_s }, rule.classes] }
          }
        end

        def root_classes(criteria)
          classes = @bases.dup
          @variants.each do |attr, mapping|
            next unless criteria.key?(attr)

            hit = mapping[criteria[attr]]
            classes << hit if hit
          end
          @compounds.each do |rule|
            classes << rule.classes if rule.criteria.all? { |attr, value| criteria[attr] == value }
          end
          classes
        end

        def merger
          Poetry::Core::Config.current.classname_merger
        end
      end
    end
  end
end
