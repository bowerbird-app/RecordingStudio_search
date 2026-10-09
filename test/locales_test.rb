# frozen_string_literal: true

require "test_helper"
require "yaml"
require "i18n"

class LocalesTest < Minitest::Test
  INTERFACE_KEYS = {
    "instant.placeholder" => "Try a name",
    "results.empty.title" => "Type a little",
    "results.empty.description" => "Hits land here as you go.",
    "results.no_hits.title" => "No luck",
    "results.no_hits.description" => "Try another word. Typos are fine.",
    "results.columns.name" => "Name",
    "results.columns.detail" => "Detail",
    "results.missing_detail" => "—"
  }.freeze

  def test_engine_ships_only_english_locale_files
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  def test_english_interface_keys_resolve_without_missing_translations
    with_gem_english_locale do
      I18n.with_locale(:en) do
        INTERFACE_KEYS.each do |key, english|
          full_key = "recording_studio.search.#{key}"
          translation = I18n.t(full_key, default: nil)

          assert_equal english, translation, "#{full_key} should resolve to #{english.inspect}"
          assert_equal english, I18n.t(full_key, raise: true)
        end
      end
    end
  end

  def test_en_yml_nests_keys_under_recording_studio_search
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")
           .fetch("recording_studio")
           .fetch("search")

    assert_equal "Try a name", tree.fetch("instant").fetch("placeholder")
    assert_equal "Type a little", tree.fetch("results").fetch("empty").fetch("title")
    assert_equal "Hits land here as you go.", tree.fetch("results").fetch("empty").fetch("description")
    assert_equal "No luck", tree.fetch("results").fetch("no_hits").fetch("title")
    assert_equal "Try another word. Typos are fine.", tree.fetch("results").fetch("no_hits").fetch("description")
    assert_equal "Name", tree.fetch("results").fetch("columns").fetch("name")
    assert_equal "Detail", tree.fetch("results").fetch("columns").fetch("detail")
    assert_equal "—", tree.fetch("results").fetch("missing_detail")
  end

  private

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def locale_tree(path, locale)
    YAML.safe_load_file(path, aliases: true).fetch(locale)
  end

  def with_gem_english_locale
    locale_path = File.expand_path(File.join(engine_locales_dir, "en.yml"))
    original = I18n.load_path.dup
    I18n.load_path |= [locale_path]
    I18n.backend.reload!
    yield
  ensure
    I18n.load_path.replace(original)
    I18n.backend.reload!
  end
end
