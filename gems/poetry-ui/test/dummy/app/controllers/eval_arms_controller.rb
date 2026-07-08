# frozen_string_literal: true

# The eval-arm endpoint (N15): GET /eval/<task>/<arm> renders one eval arm
# (<arms root>/<task>/<arm>.html.erb) inside the component_preview layout -
# the same compiled-Tailwind + live-Stimulus page the preview rig drives.
# rake eval:capture screenshots these URLs as the judge's evidence. The
# arms root defaults to the frozen corpus; POETRY_EVAL_ARMS_ROOT points the
# same rig at a benchmark run's generated arms (rake eval:benchmark:capture
# sets it - the capture rig boots this app in-process, so the env is
# visible at request time).
class EvalArmsController < ApplicationController
  def show
    root = Pathname(ENV.fetch("POETRY_EVAL_ARMS_ROOT", Poetry::Ui.root.join("eval/arms").to_s))
    path = root.join(params[:task], "#{params[:arm]}.html.erb")
    unless path.to_s.start_with?(root.to_s) && path.exist?
      raise ActionController::RoutingError, "unknown eval arm #{params[:task]}/#{params[:arm]}"
    end

    render inline: path.read, layout: "component_preview"
  end
end
