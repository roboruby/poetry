# frozen_string_literal: true

module Poetry
  module Core
    module Concerns
      # The part contract: a
      # hand-authored, machine-verified declaration of the component's
      # styling surface - the data-slot parts its DOM exposes, the state
      # attributes each part carries (and when), and the CSS custom
      # properties that seam the part to themes and controllers.
      #
      #   part "dialog-content",
      #        "The <dialog> panel - the positioning and animation surface",
      #        states: {
      #          "data-open" => "panel is open (setState pairs it with data-closed)",
      #          "data-closed" => "panel is closed or animating out"
      #        }
      #
      # Binding such a contract with types alone would keep the keys from
      # drifting while leaving every description and condition as
      # unverified prose. poetry binds the declaration to RENDERED DOM
      # instead - PartContract.verify reconciles it against every preview
      # in both directions (rendered-but-undeclared, declared-but-never-
      # rendered), so the published contract cannot lie about the anatomy.
      #
      # Declarations are OWN-CLASS ONLY, deliberately not inherited: Sheet
      # and Drawer subclass Dialog::Component yet share none of its part
      # names (sheet-content vs dialog-content) - inheritance would leak
      # phantom parts into every subclass with renamed anatomy.
      module Parts
        extend ActiveSupport::Concern

        # The kebab-case shape a declared part name (data-slot value) must match.
        PART_NAME = /\A[a-z][a-z0-9-]*\z/
        # The data-* shape a declared state attribute must match.
        STATE_ATTRIBUTE = /\Adata-[a-z][a-z0-9-]*\z/
        # A trailing * declares a dynamic family (charts' per-series
        # --color-*), matched by prefix at verify time.
        VAR_NAME = /\A--[a-z][a-z0-9-]*\*?\z/

        class_methods do
          # Declares one part of the component's rendered anatomy.
          #
          # @param name [String] the part's data-slot value
          # @param description [String] what the part is - docs/agent prose
          # @param states [Hash] state attribute => condition prose, or
          #   => { condition: "...", values: %w[...] } for valued
          #   attributes (data-side => top/right/bottom/left)
          # @param vars [Hash] CSS custom property => description
          # @return [void]
          # @raise [Poetry::Core::Error] when the class already declares a
          #   part of that name
          def part(name, description, states: {}, vars: {})
            definition = Parts.build(self, name, description, states: states, vars: vars)
            own = (@part_definitions ||= [])
            if own.any? { |existing| existing["name"] == definition["name"] }
              raise Poetry::Core::Error, "#{self}: part #{name.inspect} declared twice"
            end

            own << definition
          end

          # The declared contract, registry-shaped (plain string keys, so
          # the YAML round-trips byte-identical). Own-class only - see the
          # module docs for why subclasses never inherit anatomy.
          #
          # @return [Array<Hash>]
          def part_definitions
            @part_definitions || []
          end
        end

        class << self
          # Validates one `part` declaration and returns its registry-shaped
          # hash.
          #
          # @api private
          def build(klass, name, description, states:, vars:)
            validate_name!(klass, name)
            unless description.is_a?(String) && !description.strip.empty?
              raise Poetry::Core::Error, "#{klass}: part #{name.inspect} needs a description"
            end

            definition = { "name" => name, "description" => description }
            built_states = states.map { |attr, spec| build_state(klass, name, attr, spec) }
            definition["states"] = built_states unless built_states.empty?
            built_vars = vars.map { |var, desc| build_var(klass, name, var, desc) }
            definition["vars"] = built_vars unless built_vars.empty?
            definition
          end

          private

          def validate_name!(klass, name)
            return if name.is_a?(String) && name.match?(PART_NAME)

            raise Poetry::Core::Error,
                  "#{klass}: part name #{name.inspect} must be a kebab-case data-slot value"
          end

          def build_state(klass, part, attr, spec)
            unless attr.is_a?(String) && attr.match?(STATE_ATTRIBUTE)
              raise Poetry::Core::Error,
                    "#{klass}: part #{part.inspect} state #{attr.inspect} must be a data-* attribute"
            end

            condition, values = unpack_state(spec)
            unless condition.is_a?(String) && !condition.strip.empty?
              raise Poetry::Core::Error,
                    "#{klass}: part #{part.inspect} state #{attr} needs a condition"
            end

            state = { "attr" => attr, "condition" => condition }
            if values
              unless values.is_a?(Array) && values.any? && values.all?(String)
                raise Poetry::Core::Error,
                      "#{klass}: part #{part.inspect} state #{attr} values must be strings"
              end

              state["values"] = values
            end
            state
          end

          def unpack_state(spec)
            return [spec, nil] unless spec.is_a?(Hash)

            normalized = spec.transform_keys(&:to_s)
            [normalized["condition"], normalized["values"]]
          end

          def build_var(klass, part, var, description)
            unless var.is_a?(String) && var.match?(VAR_NAME)
              raise Poetry::Core::Error,
                    "#{klass}: part #{part.inspect} var #{var.inspect} must be a --custom-property"
            end
            unless description.is_a?(String) && !description.strip.empty?
              raise Poetry::Core::Error,
                    "#{klass}: part #{part.inspect} var #{var} needs a description"
            end

            { "name" => var, "description" => description }
          end
        end
      end
    end
  end
end
