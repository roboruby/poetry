# frozen_string_literal: true

module Poetry
  module Ui
    module ToastTrigger
      # The stamp pattern end-to-end: trigger + <template> toast + region.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_with_template(template: "poetry/ui/toast_trigger/default_preview")
        end

        # toaster: addressing - the stamp scoped to one region id.
        def addressed
          render_with_template(template: "poetry/ui/toast_trigger/addressed_preview")
        end
      end
    end
  end
end
