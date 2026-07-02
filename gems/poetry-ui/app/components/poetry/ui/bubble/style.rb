# frozen_string_literal: true

module Poetry
  module Ui
    module Bubble
      # The Bubble dictionary - shadcn new-york-v4 AI-chat set,
      # source-validated 2026-07-01 (see Bubble).
      # Variant classes live on the ROOT and style the content child via
      # *:data-[slot=bubble-content] selectors (the source's pattern);
      # hover treatments only fire when the content is a button/link.
      # NOTE tinted: oklch(from var(--primary)) relative-color math -
      # flagged to the contrast gate in the contract.
      class Style < Poetry::Core::Style
        base "group/bubble relative flex w-fit max-w-[80%] min-w-0 flex-col gap-1 " \
             "group-data-[align=end]/message:self-end data-[align=end]:self-end " \
             "data-[variant=ghost]:max-w-full"

        variant :variant, {
          default: "*:data-[slot=bubble-content]:bg-primary *:data-[slot=bubble-content]:text-primary-foreground " \
                   "[&>[data-slot=bubble-content]:is(button,a):hover]:bg-primary/80",
          secondary: "*:data-[slot=bubble-content]:bg-secondary " \
                     "*:data-[slot=bubble-content]:text-secondary-foreground " \
                     "[&>[data-slot=bubble-content]:is(button,a):hover]:" \
                     "bg-[color-mix(in_oklch,var(--secondary),var(--foreground)_5%)]",
          muted: "*:data-[slot=bubble-content]:bg-muted " \
                 "[&>[data-slot=bubble-content]:is(button,a):hover]:" \
                 "bg-[color-mix(in_oklch,var(--muted),var(--foreground)_5%)]",
          tinted: "*:data-[slot=bubble-content]:bg-[oklch(from_var(--primary)_0.93_calc(c*0.4)_h)] " \
                  "*:data-[slot=bubble-content]:text-foreground " \
                  "dark:*:data-[slot=bubble-content]:bg-[oklch(from_var(--primary)_0.3_calc(c*0.4)_h)] " \
                  "[&>[data-slot=bubble-content]:is(button,a):hover]:" \
                  "bg-[oklch(from_var(--primary)_0.88_calc(c*0.5)_h)] " \
                  "dark:[&>[data-slot=bubble-content]:is(button,a):hover]:" \
                  "bg-[oklch(from_var(--primary)_0.35_calc(c*0.5)_h)]",
          outline: "*:data-[slot=bubble-content]:border-border *:data-[slot=bubble-content]:bg-background " \
                   "[&>[data-slot=bubble-content]:is(button,a):hover]:bg-muted " \
                   "[&>[data-slot=bubble-content]:is(button,a):hover]:text-foreground " \
                   "dark:[&>[data-slot=bubble-content]:is(button,a):hover]:bg-input/30",
          ghost: "border-none *:data-[slot=bubble-content]:rounded-none *:data-[slot=bubble-content]:bg-transparent " \
                 "*:data-[slot=bubble-content]:p-0 " \
                 "[&>[data-slot=bubble-content]:is(button,a):hover]:bg-muted " \
                 "[&>[data-slot=bubble-content]:is(button,a):hover]:text-foreground " \
                 "dark:[&>[data-slot=bubble-content]:is(button,a):hover]:bg-muted/50",
          destructive: "*:data-[slot=bubble-content]:bg-destructive/10 *:data-[slot=bubble-content]:text-destructive " \
                       "dark:*:data-[slot=bubble-content]:bg-destructive/20 " \
                       "[&>[data-slot=bubble-content]:is(button,a):hover]:bg-destructive/20 " \
                       "dark:[&>[data-slot=bubble-content]:is(button,a):hover]:bg-destructive/30"
        }

        element :group, "flex min-w-0 flex-col gap-2"

        element :content, "w-fit max-w-full min-w-0 overflow-hidden rounded-xl border border-transparent " \
                          "px-3 py-2 text-sm leading-relaxed wrap-break-word group-data-[align=end]/bubble:self-end " \
                          "[button]:text-left [button,a]:transition-colors [button,a]:outline-none " \
                          "[button,a]:focus-visible:border-ring [button,a]:focus-visible:ring-3 " \
                          "[button,a]:focus-visible:ring-ring/50"

        # The source's side x align cva, expressed as data-attribute
        # selectors (the component stamps data-side/data-align; one static
        # dictionary string keeps safelist + Verifier whole).
        element :reactions, "absolute z-10 flex w-fit shrink-0 items-center justify-center gap-1 rounded-full " \
                            "bg-muted px-1.5 py-0.5 text-sm ring-3 ring-card has-[button]:p-0 " \
                            "data-[side=top]:top-0 data-[side=top]:-translate-y-3/4 " \
                            "data-[side=bottom]:bottom-0 data-[side=bottom]:translate-y-3/4 " \
                            "data-[align=start]:left-3 data-[align=end]:right-3"
      end
    end
  end
end
