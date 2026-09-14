# frozen_string_literal: true

class InstantPeopleController < ApplicationController
  def index
    @hits = User.none
  end
end
