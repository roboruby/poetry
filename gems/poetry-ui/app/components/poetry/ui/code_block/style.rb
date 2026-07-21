# frozen_string_literal: true

module Poetry
  module Ui
    module CodeBlock
      # The panel look, syntax palette values, .hll tint, and line-number
      # chrome are theme-owned (cn-code-block + descendant rules, all nine
      # themes); the dictionary carries the STRUCTURE - scroll container,
      # counters, and the token map wiring rouge's classes to the seven
      # --syntax-* vars the theme defines.
      class Style < Poetry::Core::Style
        base "cn-code-block group/code relative"

        element :pre, "overflow-x-auto p-4 [counter-reset:line]"

        # The token map: rouge's short classes -> the theme's syntax vars.
        # .line blocks make .hll tints span the full row.
        element :code, "block min-w-max font-mono text-sm [&_.line]:block " \
                       "[&_:is(.k,.kd,.kn,.kp,.kr,.kt,.kv)]:text-(--syntax-keyword) " \
                       "[&_:is(.kc,.l,.ld,.m,.mb,.mf,.mh,.mi,.il,.mo,.mx)]:text-(--syntax-constant) " \
                       "[&_:is(.sb,.bp,.ne,.nl,.py,.nv,.vc,.vg,.vi,.vm,.o,.ow)]:text-(--syntax-constant) " \
                       "[&_:is(.s,.sa,.sc,.dl,.sd,.s2,.se,.sh,.sx,.s1,.ss)]:text-(--syntax-string) " \
                       "[&_:is(.nb,.nc,.no,.nn)]:text-(--syntax-entity) " \
                       "[&_:is(.na,.nt,.sr)]:text-(--syntax-markup) " \
                       "[&_:is(.nd,.nf,.fm)]:text-(--syntax-function) " \
                       "[&_:is(.c,.ch,.cd,.cm,.cp,.cpf,.c1,.cs)]:text-(--syntax-comment)"

        element :copy, "absolute top-2 end-2"

        element :icon_stack, "relative flex size-4 items-center justify-center"
        element :icon_copy, "absolute inset-0 m-auto transition-all duration-200 " \
                            "[[data-copied]_&]:scale-0 [[data-copied]_&]:opacity-0"
        element :icon_check, "absolute inset-0 m-auto scale-0 opacity-0 transition-all duration-200 " \
                             "[[data-copied]_&]:scale-100 [[data-copied]_&]:opacity-100"
      end
    end
  end
end
