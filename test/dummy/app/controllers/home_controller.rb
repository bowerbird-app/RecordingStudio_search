class HomeController < ApplicationController
  def index
    @q = params[:q].to_s
    if @q.present?
      @users = User.search(@q, limit: 20)
      @pages = Page.search(@q, limit: 20)
      @notes = Note.search(@q, limit: 20)
    else
      @users = User.none
      @pages = Page.none
      @notes = Note.none
    end
  end
end
