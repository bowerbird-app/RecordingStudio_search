# frozen_string_literal: true

RecordingStudioSearch::Engine.routes.draw do
  get "instant_search", to: "instant_searches#show", as: :instant_search
end
