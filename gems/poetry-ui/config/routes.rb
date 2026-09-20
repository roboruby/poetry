# frozen_string_literal: true

# Mounted by the host (mount Poetry::Ui::Engine => "/poetry"); serves the
# LLM-facing docs generated live from the component registry.
Poetry::Ui::Engine.routes.draw do
  get "llms.txt", to: "poetry/ui/llms#index", format: false
  get "llms-full.txt", to: "poetry/ui/llms#full", format: false
end
