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

  MISSING_DETAIL_KEY = "recording_studio.search.results.missing_detail"
  DETAIL_CELL = "tbody tr td:nth-child(2)"

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

    # Force I18n to initialize before assertions (order-independent).
    I18n.t("recording_studio.search.results.empty.title")

    assert_equal "HOST missing mark", I18n.t(MISSING_DETAIL_KEY, raise: true)
    assert_equal "HOST missing mark", RecordingStudio.t(MISSING_DETAIL_KEY)
    refute_equal "—", I18n.t(MISSING_DETAIL_KEY)

    get instant_people_path

    assert_response :success
    assert_select "h3", text: "Type a little"

    get search_i18n_probe_path

    assert_response :success
    assert_select "td", text: "Solo"
    assert_select DETAIL_CELL, text: "HOST missing mark"
    refute_select DETAIL_CELL, text: "—"

    # Same Detail cell shows gem English when the loaded host override is gone.
    delete_loaded_translation!(:en, MISSING_DETAIL_KEY)
    refute I18n.exists?(MISSING_DETAIL_KEY, :en)
    assert_equal "—", RecordingStudio.t(MISSING_DETAIL_KEY)

    get search_i18n_probe_path

    assert_response :success
    assert_select DETAIL_CELL, text: "—"
    refute_select DETAIL_CELL, text: "HOST missing mark"
  ensure
    I18n.reload!
  end

  private

  def delete_loaded_translation!(locale, full_key)
    I18n.exists?(full_key, locale)
    parts = full_key.split(".").map(&:to_sym)
    leaf = parts.pop
    translations = I18n.backend.send(:translations)
    locale_key = locale.to_sym
    translations[locale_key] = translations[locale_key].dup if translations[locale_key].frozen?

    node = translations[locale_key]
    parts.each do |part|
      break unless node.is_a?(Hash) && node[part].is_a?(Hash)

      node[part] = node[part].dup if node[part].frozen?
      node = node[part]
    end
    node.delete(leaf) if node.is_a?(Hash)
  end
end
