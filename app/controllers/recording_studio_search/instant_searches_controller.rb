# frozen_string_literal: true

module RecordingStudioSearch
  # Thin Turbo Frame endpoint. Allowlisted models only. Blank q is empty, not everyone.
  class InstantSearchesController < ApplicationController
    helper ResultsHelper

    def show
      @query = search_query
      @hits = InstantSearch.hits_for(requested_models, @query, limit: 20)
      render layout: false
    end

    private

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
