# frozen_string_literal: true

Rails.application.routes.draw do
  mount Poetry::Core::Engine => "/poetry-core"
end
