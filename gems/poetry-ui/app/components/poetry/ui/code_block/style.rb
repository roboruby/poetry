# frozen_string_literal: true

module Poetry
  module Ui
    module CodeBlock
      # The CodeBlock dictionary: upstream's code-block anatomy
      # (shadcn@4.23.0) - the structural classes per part, transcribed from
      # the styled source - plus poetry's token map on the code element,
      # which colors rouge's classes through the theme's seven --syntax-*
      # vars. The look (panel, header, line tints, the +/- markers) lives
      # in each theme's cn-code-block-* rules.
      class Style < Poetry::Core::Style
        base "cn-code-block group/code-block relative flex w-full min-w-0 flex-col overflow-hidden"

        variant :variant, {
          default: "cn-code-block-variant-default",
          destructive: "cn-code-block-variant-destructive"
        }

        element :header, "cn-code-block-header flex min-w-0 shrink-0 items-center " \
                         "*:has-[>[data-slot=code-block-title]]:min-w-0"
        element :title, "cn-code-block-title min-w-0 truncate [&_svg]:pointer-events-none " \
                        "[&_svg]:inline-block [&_svg]:align-middle"
        # In the header the actions sit in the row; as a direct child of the
        # root they float in the corner, shown on hover or focus (always on a
        # coarse pointer).
        element :actions, "cn-code-block-actions ms-auto flex shrink-0 items-center " \
                          "[[data-slot=code-block]>&]:absolute [[data-slot=code-block]>&]:z-10 " \
                          "[[data-slot=code-block]>&]:opacity-0 [[data-slot=code-block]>&]:transition-opacity " \
                          "[[data-slot=code-block]>&]:group-focus-within/code-block:opacity-100 " \
                          "[[data-slot=code-block]>&]:group-hover/code-block:opacity-100 " \
                          "[[data-slot=code-block]>&]:pointer-coarse:opacity-100"
        element :content, "cn-code-block-content min-h-0 min-w-0 scroll-fade-x scrollbar-thin overflow-auto " \
                          "text-start font-mono outline-none [counter-reset:line] data-wrap:scroll-fade-y " \
                          "data-wrap:wrap-break-word data-wrap:whitespace-pre-wrap"
        element :code, "cn-code-block-code grid min-h-lh min-w-max content-start " \
                       "in-data-numbered:grid-cols-[auto_1fr] in-data-wrap:min-w-0 " \
                       "[&_:is(.k,.kd,.kn,.kp,.kr,.kt,.kv)]:text-(--syntax-keyword) " \
                       "[&_:is(.kc,.l,.ld,.m,.mb,.mf,.mh,.mi,.il,.mo,.mx)]:text-(--syntax-constant) " \
                       "[&_:is(.sb,.bp,.ne,.nl,.py,.nv,.vc,.vg,.vi,.vm,.o,.ow)]:text-(--syntax-constant) " \
                       "[&_:is(.s,.sa,.sc,.dl,.sd,.s2,.se,.sh,.sx,.s1,.ss)]:text-(--syntax-string) " \
                       "[&_:is(.nb,.nc,.no,.nn)]:text-(--syntax-entity) " \
                       "[&_:is(.na,.nt,.sr)]:text-(--syntax-markup) " \
                       "[&_:is(.nd,.nf,.fm)]:text-(--syntax-function) " \
                       "[&_:is(.c,.ch,.cd,.cm,.cp,.cpf,.c1,.cs)]:text-(--syntax-comment)"
        element :line, "cn-code-block-line relative block min-h-lh after:absolute after:top-0 after:select-none " \
                       "in-data-numbered:col-span-2 in-data-numbered:grid in-data-numbered:grid-cols-subgrid " \
                       "in-data-numbered:[counter-increment:line] in-data-numbered:before:content-[counter(line)] " \
                       "in-data-numbered:before:select-none " \
                       "in-data-numbered:supports-[content:counter(line)_/_'']:before:content-[counter(line)_/_'']"
        # The default line carries no hook: no theme styles it.
        element :line_default, ""
        element :line_added, "cn-code-block-line-variant-added"
        element :line_removed, "cn-code-block-line-variant-removed"
        element :line_highlighted, "cn-code-block-line-variant-highlighted"
        element :line_content, "min-w-0"
        element :footer, "cn-code-block-footer flex min-w-0 shrink-0 items-center"

        element :icon_stack, "relative flex size-4 items-center justify-center"
        element :icon_copy, "absolute inset-0 m-auto transition-all duration-200 " \
                            "[[data-copied]_&]:scale-0 [[data-copied]_&]:opacity-0"
        element :icon_check, "absolute inset-0 m-auto scale-0 opacity-0 transition-all duration-200 " \
                             "[[data-copied]_&]:scale-100 [[data-copied]_&]:opacity-100"
      end
    end
  end
end
