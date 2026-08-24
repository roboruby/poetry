# frozen_string_literal: true

module Poetry
  module Ui
    module Questionnaire
      # Style dictionary for the Questionnaire family: structural classes
      # inline; the visual voice lives in each theme's cn-questionnaire-*
      # rules.
      class Style < Poetry::Core::Style
        base "cn-questionnaire flex w-full min-w-0 flex-col"

        element :progress, "cn-questionnaire-progress min-h-[1lh] w-fit min-w-[14ch] font-medium " \
                           "text-muted-foreground tabular-nums"
        element :item, "cn-questionnaire-item min-w-0 border-0 p-0 outline-none"
        element :title, "cn-questionnaire-title cn-font-heading text-pretty"
        element :description, "cn-questionnaire-description text-pretty text-muted-foreground"
        element :choices, "cn-questionnaire-choices group/questionnaire-choices grid min-w-0"
        element :choice, "cn-questionnaire-choice group/questionnaire-choice relative flex " \
                         "min-h-11 cursor-pointer items-start text-start transition-colors " \
                         "outline-none select-none data-disabled:pointer-events-none " \
                         "data-disabled:cursor-not-allowed data-disabled:opacity-50"
        element :choice_input, "absolute inset-0 z-10 size-full cursor-pointer opacity-0"
        element :choice_indicator, "cn-questionnaire-choice-indicator pointer-events-none " \
                                   "relative flex shrink-0 items-center justify-center border " \
                                   "group-data-[type=radio]/questionnaire-choice:rounded-full"
        element :choice_indicator_dot, "cn-questionnaire-choice-indicator-dot hidden rounded-full " \
                                       "group-data-[type=checkbox]/questionnaire-choice:hidden " \
                                       "group-data-checked/questionnaire-choice:block"
        element :choice_indicator_check, "cn-questionnaire-choice-indicator-check hidden " \
                                         "group-data-[type=radio]/questionnaire-choice:hidden " \
                                         "group-data-checked/questionnaire-choice:block"
        element :choice_label, "cn-questionnaire-choice-content flex min-w-0 flex-1 flex-col leading-snug"
        element :choice_description, "cn-questionnaire-choice-description"
        element :choice_shortcut, "cn-questionnaire-shortcut pointer-events-none ms-auto hidden shrink-0 " \
                                  "group-data-[shortcut]/questionnaire-choice:inline-flex"
        element :input_wrapper, "cn-questionnaire-input-wrapper group/questionnaire-input " \
                                "relative min-w-0"
        element :input, "cn-questionnaire-input min-h-11 w-full min-w-0 " \
                        "transition-[color,box-shadow,background-color] outline-none " \
                        "disabled:pointer-events-none disabled:cursor-not-allowed " \
                        "disabled:opacity-50 sm:min-h-0 selection:bg-primary " \
                        "selection:text-primary-foreground placeholder:text-muted-foreground"
        element :error, "cn-questionnaire-error text-destructive"
        element :actions, "cn-questionnaire-actions grid min-h-11 w-full " \
                          "grid-cols-[minmax(0,1fr)_auto_auto] items-center"
        element :previous, "col-start-1 row-start-1 min-h-11 justify-self-start sm:min-h-0"
        element :skip, "col-start-2 row-start-1 min-h-11 justify-self-end sm:min-h-0"
        element :next, "col-start-3 row-start-1 min-h-11 justify-self-end sm:min-h-0"
        element :submit, "col-start-3 row-start-1 min-h-11 justify-self-end sm:min-h-0"
      end
    end
  end
end
