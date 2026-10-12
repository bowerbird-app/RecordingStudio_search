# frozen_string_literal: true

# Test-only probe: renders the gem instant-search results partial for a row
# with no email and no body so `results.missing_detail` appears on a real page.
class SearchI18nProbesController < ApplicationController
  ResultRow = Struct.new(:name, :email, :body, keyword_init: true)

  def show
    @hits = [ResultRow.new(name: "Solo")]
    render layout: false
  end
end
