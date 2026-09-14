# frozen_string_literal: true

module RecordingStudioSearch
  # Thin Turbo Frame endpoint. Runs Model.search / RecordingStudioSearch.search
  # for allowlisted models only. Does not change search backends.
  class InstantSearchesController < ApplicationController
    helper ResultsHelper

    def show
      @hits = hits_for(search_query)
      render layout: false
    end

    private

    def hits_for(query)
      models = InstantSearch.allowed_models(requested_models)
      return empty_hits(models) if models.empty? || query.blank?

      RecordingStudioSearch.search(models.one? ? models.first : models, query, limit: 20)
    end

    def empty_hits(models)
      return {} if models.empty?
      return models.first.none if models.one?

      models.index_with(&:none)
    end

    def requested_models
      raw = params[:models]
      raw = raw.values if raw.respond_to?(:values)
      Array(raw)
    end

    def search_query
      params[InstantSearch.search_param(params)].to_s
    end

    def frame_id
      raw = params[:frame_id].to_s
      raw.match?(/\A[\w-]+\z/) ? raw : "instant_search_results"
    end
    helper_method :frame_id
  end
end
