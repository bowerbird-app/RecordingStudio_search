# frozen_string_literal: true

class GroupSearchesController < ApplicationController
  GROUPS = %w[everyone example.com hopper.test].freeze

  def index
    @q = params[:q].to_s
    @group = GROUPS.include?(params[:group].to_s) ? params[:group].to_s : "everyone"
    people = people_in_group
    @people = @q.present? ? people.search(@q, limit: 20) : User.none
  end

  private

  def people_in_group
    case @group
    when "example.com"
      User.where("email ILIKE ?", "%@example.com")
    when "hopper.test"
      User.where("email ILIKE ?", "%@hopper.test")
    else
      User.all
    end
  end
end
