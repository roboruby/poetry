# frozen_string_literal: true

# The eval-arm endpoint (N15): GET /eval/<task>/<arm> renders one frozen
# eval arm (eval/arms/<task>/<arm>.html.erb) inside the component_preview
# layout - the same compiled-Tailwind + live-Stimulus page the preview rig
# drives. rake eval:capture screenshots these URLs as the judge's evidence.
class EvalArmsController < ApplicationController
  def show
    root = Poetry::Ui.root.join("eval/arms")
    path = root.join(params[:task], "#{params[:arm]}.html.erb")
    unless path.to_s.start_with?(root.to_s) && path.exist?
      raise ActionController::RoutingError, "unknown eval arm #{params[:task]}/#{params[:arm]}"
    end

    render inline: path.read, layout: "component_preview"
  end
end
