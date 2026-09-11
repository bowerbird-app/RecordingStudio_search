# frozen_string_literal: true

class PeopleController < ApplicationController
  def index
    @q = params[:q].to_s
    # Blank Model.search returns the full relation. A lookup page should
    # treat empty q as no hits, not "everyone".
    @people = @q.present? ? User.search(@q, limit: 20) : User.none
  end
end
