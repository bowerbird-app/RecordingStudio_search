class HomeController < ApplicationController
  def index
    @q = params[:q].to_s
    if @q.present?
      results = RecordingStudioSearch.search([User, Page, Note], @q, limit: 20)
      @users = results[User]
      @pages = results[Page]
      @notes = results[Note]
    else
      @users = User.none
      @pages = Page.none
      @notes = Note.none
    end
  end
end
