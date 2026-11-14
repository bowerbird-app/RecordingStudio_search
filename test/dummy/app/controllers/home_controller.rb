class HomeController < ApplicationController
  def index
    @q = params[:q].to_s
    if @q.present?
      @users = User.search(@q, limit: 20, unscoped: true)
      @pages = scoped_page_search
      @notes = Note.search(@q, limit: 20, unscoped: true)
    else
      @users = User.none
      @pages = Page.none
      @notes = Note.none
    end
  end

  private

  def scoped_page_search
    root = current_root_recording
    return Page.none if Current.actor.blank? || root.blank?

    Page.search(@q, actor: Current.actor, root: root, limit: 20)
  end
end
