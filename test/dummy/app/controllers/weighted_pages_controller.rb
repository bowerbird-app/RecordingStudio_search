# frozen_string_literal: true

class WeightedPagesController < ApplicationController
  def index
    ensure_demo_pages
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

  private

  def ensure_demo_pages
    widgets = Page.find_or_create_by!(title: "Widgets") do |page|
      page.body = "unrelated copy"
    end
    other = Page.find_or_create_by!(title: "Something else") do |page|
      page.body = "Widgets appear in the body only"
    end
    DummyAccess.record_under_workspace!(widgets, actor: Current.actor)
    DummyAccess.record_under_workspace!(other, actor: Current.actor)
  end
end
