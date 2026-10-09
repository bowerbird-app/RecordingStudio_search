# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class HostLocaleOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  HOST_OVERRIDE = Rails.root.join(
    "test/fixtures/locales/recording_studio_search_host_override.en.yml"
  ).to_s

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
      account.name = "Ada Admin"
    end
    sign_in @user
  end

  test "host locale override wins over gem empty-state title on the instant page" do
    original_load_path = I18n.load_path.dup

    begin
      I18n.load_path |= [HOST_OVERRIDE]
      I18n.backend.reload!

      get instant_people_path

      assert_response :success
      assert_match "Host empty nudge", response.body
      refute_match "Type a little", response.body
      assert_match "Hits land here as you go.", response.body
    ensure
      I18n.load_path.replace(original_load_path)
      I18n.backend.reload!
    end
  end

  test "default english empty-state title returns after the override is restored" do
    get instant_people_path

    assert_response :success
    assert_match "Type a little", response.body
    refute_match "Host empty nudge", response.body
  end
end
