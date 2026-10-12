# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

# Proves a host nested `recording_studio.search.*` override in
# config/locales wins over gem English at boot. Uses
# results.missing_detail (rarely shown em-dash placeholder) so other
# instant-search assertions keep default English. Does not touch
# I18n.load_path.
class SearchBootOrderHostOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @original_load_path = I18n.load_path.dup
    @user = User.find_or_create_by!(email: "admin@admin.com") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
      account.name = "Ada Admin"
    end
    sign_in @user
  end

  teardown do
    assert_equal @original_load_path, I18n.load_path,
                 "tests must not leave I18n.load_path modified"
  end

  test "host nested locale override wins on missing detail key" do
    host_locale = Rails.root.join("config/locales/recording_studio_search_host.en.yml")
    assert File.exist?(host_locale), "expected host override file at #{host_locale}"

    assert_equal "HOST missing mark",
                 I18n.t("recording_studio.search.results.missing_detail", raise: true)

    get instant_people_path

    assert_response :success
    assert_match "Type a little", response.body
    refute_match "HOST missing mark", response.body
    assert_equal "HOST missing mark",
                 I18n.t("recording_studio.search.results.missing_detail", raise: true)

    get search_i18n_probe_path

    assert_response :success
    assert_select "td", text: "HOST missing mark"
    assert_select "td", text: "Solo"
  end
end
