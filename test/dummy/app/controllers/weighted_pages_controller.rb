# frozen_string_literal: true

class WeightedPagesController < ApplicationController
  def index
    @q = params[:q].to_s
    @pages = if @q.present?
      RecordingStudioSearch::TrigramSearcher.call(
        RecordingStudioSearch::AccessibleScope.relation_for(Page, Current.actor),
        @q,
        limit: 20
      ).to_a
    else
      []
    end
  end
end
