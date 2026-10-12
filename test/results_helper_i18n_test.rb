# frozen_string_literal: true

require "test_helper"
require "i18n"
require "active_support/core_ext/string/inflections"
require_relative "../app/helpers/recording_studio_search/results_helper"

class ResultsHelperI18nTest < Minitest::Test
  class HelperHost
    include RecordingStudioSearch::ResultsHelper

    def t(key, **)
      I18n.t(key, **)
    end
  end

  Row = Struct.new(:name, :email, :body, :title, keyword_init: true)

  def setup
    @locale_path = File.expand_path("../config/locales/en.yml", __dir__)
    @original_load_path = I18n.load_path.dup
    @original_backend = I18n.backend
    @original_available = I18n.available_locales
    I18n.backend = I18n::Backend::Simple.new
    I18n.load_path = [@locale_path]
    I18n.backend.load_translations
    I18n.available_locales = %i[en fr]
    @helper = HelperHost.new
  end

  def teardown
    I18n.load_path.replace(@original_load_path)
    I18n.backend = @original_backend
    I18n.available_locales = @original_available
    I18n.backend.reload! if I18n.backend.respond_to?(:reload!)
  end

  def test_collection_label_returns_raw_english_model_name
    assert_equal "Users", @helper.instant_search_collection_label(UserStub)
    assert_equal "Pages", @helper.instant_search_collection_label("Page")
  end

  def test_translated_collection_label_defaults_to_raw_english
    I18n.with_locale(:en) do
      assert_equal "Users", @helper.instant_search_translated_collection_label("Users")
      assert_equal "", @helper.instant_search_translated_collection_label("")
    end
  end

  def test_translated_collection_label_uses_host_override_and_falls_back_when_missing
    I18n.backend.store_translations(:fr, {
                                      recording_studio: {
                                        search: {
                                          results: {
                                            collections: {
                                              users: "Utilisateurs"
                                            }
                                          }
                                        }
                                      }
                                    })

    I18n.with_locale(:fr) do
      assert_equal "Utilisateurs", @helper.instant_search_translated_collection_label("Users")
      assert_equal "Pages", @helper.instant_search_translated_collection_label("Pages")
    end
  end

  def test_missing_detail_english_default_and_french_override
    I18n.with_locale(:en) do
      assert_equal "—", @helper.instant_search_row_detail(Row.new(name: "Solo"))
    end

    I18n.backend.store_translations(:fr, {
                                      recording_studio: {
                                        search: {
                                          results: {
                                            missing_detail: "manquant"
                                          }
                                        }
                                      }
                                    })

    I18n.with_locale(:fr) do
      assert_equal "manquant", @helper.instant_search_row_detail(Row.new(name: "Solo"))
    end
  end

  def test_row_name_and_detail_keep_model_data_raw
    row = Row.new(name: "Ada", email: "ada@example.com", body: "long body text")

    assert_equal "Ada", @helper.instant_search_row_name(row)
    assert_equal "ada@example.com", @helper.instant_search_row_detail(row)
  end

  class UserStub
    def self.name
      "User"
    end
  end
end
