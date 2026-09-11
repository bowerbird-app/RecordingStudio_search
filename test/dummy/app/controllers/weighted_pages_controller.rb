# frozen_string_literal: true

class WeightedPagesController < ApplicationController
  def index
    ensure_demo_pages
    @q = params[:q].to_s
    @pages = if @q.present?
      RecordingStudioSearch::TrigramSearcher.call(Page.all, @q, limit: 20).to_a
    else
      []
    end
  end

  private

  def ensure_demo_pages
    Page.find_or_create_by!(title: "Widgets") do |page|
      page.body = "unrelated copy"
    end
    Page.find_or_create_by!(title: "Something else") do |page|
      page.body = "Widgets appear in the body only"
    end
  end
end
