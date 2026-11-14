# frozen_string_literal: true

class PeopleController < ApplicationController
  def index
    @q = params[:q].to_s
    # People are not recordings. unscoped skips the access scope.
    # A blank box stays empty instead of listing everyone.
    @people = @q.present? ? User.search(@q, limit: 20, unscoped: true) : User.none
  end
end
