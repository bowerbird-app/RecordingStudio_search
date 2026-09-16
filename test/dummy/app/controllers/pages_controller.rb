# frozen_string_literal: true

class PagesController < ApplicationController
  def show
    @page = Page.find(params[:id])
  end
end
