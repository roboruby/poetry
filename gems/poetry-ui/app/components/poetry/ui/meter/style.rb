# frozen_string_literal: true

module Poetry
  module Ui
    module Meter
      # Progress's chrome verbatim (the NumberField composition precedent):
      # the template calls Progress::Style.css for track/indicator/label/
      # value, so the themes' cn-progress-* rules dress meters too - zero
      # new theme CSS, and a theme that restyles progress restyles meters
      # with it. The root only stacks.
      class Style < Poetry::Core::Style
        base "flex flex-wrap gap-3"
      end
    end
  end
end
