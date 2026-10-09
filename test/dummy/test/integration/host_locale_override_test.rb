# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class HostLocaleOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
      account.name = "Ada Admin"
    end
    sign_in @user
  end

  test "host locale file overrides gem empty-state title on the instant page" do
    get instant_people_path

    assert_response :success
    assert_match "Host empty nudge", response.body
    refute_match "Type a little", response.body
    assert_match "Hits land here as you go.", response.body
  end
end
