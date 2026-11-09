# frozen_string_literal: true

Rails.application.routes.draw do
  root to: proc { [200, { "Content-Type" => "text/plain" }, ["poetry-motion dummy"]] }
end
