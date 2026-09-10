# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class SearchHomeTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
      account.name = "Ada Admin"
    end
    @user.update!(name: "Ada Admin")
    sign_in @user
  end

  test "blank home shows the search form" do
    get root_path
    assert_response :success
    assert_select "h1", text: /Search/
    assert_match "Look up", response.body
    refute_match "Ada Admin", response.body
  end

  test "trigram search finds a person" do
    get root_path, params: { q: "Ada" }
    assert_response :success
    assert_match "Ada Admin", response.body
  end
end
