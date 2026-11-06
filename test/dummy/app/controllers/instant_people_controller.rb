# frozen_string_literal: true

class InstantPeopleController < ApplicationController
  def index
    @hits = Page.none
  end
end
