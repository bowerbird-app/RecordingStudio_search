# frozen_string_literal: true

require "test_helper"

class LocalesLoadPathTest < ActiveSupport::TestCase
  test "rails i18n load path includes the search gem english locale file" do
    locale_path = RecordingStudioSearch::Engine.root.join("config/locales/en.yml").to_s

    assert_includes I18n.load_path.map { |path| File.expand_path(path) }, File.expand_path(locale_path)
  end

  test "instant search default placeholder English is available to the host" do
    I18n.with_locale(:en) do
      assert_equal "Try a name", I18n.t("recording_studio.search.instant.placeholder", raise: true)
      assert_equal "Host empty nudge", I18n.t("recording_studio.search.results.empty.title", raise: true)
      assert_equal "No luck", I18n.t("recording_studio.search.results.no_hits.title", raise: true)
      assert_equal "Name", I18n.t("recording_studio.search.results.columns.name", raise: true)
      assert_equal "Detail", I18n.t("recording_studio.search.results.columns.detail", raise: true)
    end
  end
end
