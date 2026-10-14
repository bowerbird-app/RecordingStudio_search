# frozen_string_literal: true

require "test_helper"
require "action_controller"
require "action_view"
require "yaml"
require "tmpdir"

# Behavioral coverage for RecordingStudio.t with this gem's registered English.
# No gem-local Translation helper — call sites and assertions use the base API.
class TranslationTest < Minitest::Test
  GEM_KEYS = {
    "recording_studio.search.instant.placeholder" => "Try a name",
    "recording_studio.search.results.empty.title" => "Type a little",
    "recording_studio.search.results.empty.description" => "Hits land here as you go.",
    "recording_studio.search.results.no_hits.title" => "No luck",
    "recording_studio.search.results.no_hits.description" => "Try another word. Typos are fine.",
    "recording_studio.search.results.columns.name" => "Name",
    "recording_studio.search.results.columns.detail" => "Detail",
    "recording_studio.search.results.missing_detail" => "—"
  }.freeze

  SEARCH_EN_YML = File.expand_path("../config/locales/en.yml", __dir__)

  def setup
    @previous_locales = I18n.available_locales
    I18n.available_locales = (@previous_locales + %i[en fr de xx]).uniq
    ensure_search_english_registered!
    reset_english_backend!
    clear_locale_translations!(:de)
    clear_locale_translations!(:fr)
    clear_locale_translations!(:xx)
  end

  def teardown
    I18n.locale = I18n.default_locale
    I18n.available_locales = @previous_locales if @previous_locales
    reset_english_backend!
    clear_locale_translations!(:de)
    clear_locale_translations!(:fr)
    clear_locale_translations!(:xx)
  end

  def test_english_locale_resolves_every_sample_gem_key_from_en_yml
    I18n.with_locale(:en) do
      GEM_KEYS.each do |key, english|
        assert_equal english, RecordingStudio.t(key)
        assert_equal english, RecordingStudio::Translation.t(key)
      end
    end
  end

  def test_registered_search_keys_appear_in_shipped_english_table
    RecordingStudio::Translation.reset_shipped_english!
    table = RecordingStudio::Translation.shipped_english

    GEM_KEYS.each do |key, english|
      assert_equal english, table.fetch(key), "#{key} must be in the merged shipped-english table"
    end
    assert_predicate table, :frozen?
  end

  def test_deleted_loaded_english_falls_back_to_shipped_gem_en_yml_text
    GEM_KEYS.each_key do |key|
      delete_loaded_translation!(:en, key)
      delete_loaded_translation!(:fr, key)
    end

    GEM_KEYS.each do |key, english|
      refute I18n.exists?(key, :en), "#{key} must be absent from loaded :en"
      I18n.with_locale(:en) do
        assert_equal english, RecordingStudio.t(key)
        refute_match(/translation missing/i, RecordingStudio.t(key))
      end
      I18n.with_locale(:fr) do
        assert_equal english, RecordingStudio.t(key)
        refute_match(/translation missing/i, RecordingStudio.t(key))
      end
    end
  ensure
    I18n.backend.store_translations(:en, gem_english_tree)
  end

  def test_missing_locale_falls_back_to_loaded_english
    I18n.with_locale(:de) do
      GEM_KEYS.each do |key, english|
        refute I18n.exists?(key, :de), "#{key} must be absent in :de for this test"
        assert_equal english, RecordingStudio.t(key),
                     "#{key} should fall back to loaded English when :de has no file"
        refute_match(/translation missing/i, RecordingStudio.t(key))
      end
    end
  end

  def test_does_not_raise_for_missing_locale_when_callers_use_raise_on_missing_style_lookups
    key = "recording_studio.search.results.empty.title"
    I18n.with_locale(:de) do
      assert_raises(I18n::MissingTranslationData) do
        I18n.t(key, locale: :de, raise: true)
      end

      assert_equal "Type a little", RecordingStudio.t(key)
    end
  end

  def test_parity_matrix_non_gem_keys_match_i18n_t
    # rubocop:disable Style/FormatStringToken
    I18n.backend.store_translations(:en, {
                                      probe: {
                                        greet: "Hi %{name}",
                                        empty: "",
                                        nil_value: nil,
                                        nest: { a: "A" },
                                        html_key_html: "<b>x</b>",
                                        items: { one: "one item", other: "%{count} items" }
                                      }
                                    })
    I18n.backend.store_translations(:de, { probe: { greet: "Hallo %{name}" } })
    # rubocop:enable Style/FormatStringToken

    I18n.with_locale(:de) do
      assert_parity("probe.greet", name: "M")
      assert_parity("probe.missing")
      assert_parity("probe.missing", default: "D")
      assert_parity("probe.empty")
      assert_parity("probe.nil_value")
      assert_parity("probe.nest")
      assert_parity("probe.items", count: 1)
      assert_parity("probe.items", count: 5)
      assert_parity(:"probe.greet", name: "M")
      assert_parity(%w[probe.missing probe.greet], name: "M")
      assert_parity("greet", scope: "probe", name: "M")
      assert_raise_parity("probe.missing", raise: true)
      assert_parity("probe.greet", locale: :en, name: "M")
      assert_parity("probe.html_key_html")
    end
  end

  def test_parity_matrix_gem_keys_cover_missing_default_raise_nil_empty_hash_and_related_options
    key = "recording_studio.search.results.empty.title"
    missing = "recording_studio.search.results.missing_key_for_parity"

    # rubocop:disable-next Style/FormatStringToken
    I18n.backend.store_translations(:en, {
                                      recording_studio: {
                                        search: {
                                          results: {
                                            nil_value: nil,
                                            empty_value: "",
                                            nest: { a: "A" },
                                            html_key_html: "<i>g</i>",
                                            items: { one: "one", other: "%{count} many" },
                                            greet: "Hi %{name}"
                                          }
                                        }
                                      }
                                    })

    I18n.with_locale(:en) do
      assert_equal I18n.t(key), RecordingStudio.t(key)
      assert_equal "Type a little", RecordingStudio.t(key, default: "Ignored when present")
    end

    I18n.with_locale(:de) do
      assert_equal "Type a little", RecordingStudio.t(key),
                   "missing active locale uses loaded English"
      assert_match(/translation missing/i, I18n.t(key))

      assert_parity(missing)
      assert_parity(missing, default: "D")
      assert_raise_parity(missing, raise: true)

      I18n.backend.store_translations(:de, {
                                        recording_studio: {
                                          search: { results: { empty: { title: "DE Type a little" } } }
                                        }
                                      })
      assert_equal "DE Type a little", RecordingStudio.t(key)
      assert_equal I18n.t(key), RecordingStudio.t(key),
                   "no English fallback when the active locale has the key"

      assert_parity("recording_studio.search.results.nil_value")
      assert_equal "", RecordingStudio.t("recording_studio.search.results.empty_value")
      assert_match(/translation missing/i, I18n.t("recording_studio.search.results.empty_value"))

      assert_equal(
        I18n.t("recording_studio.search.results.nest", locale: :en),
        RecordingStudio.t("recording_studio.search.results.nest")
      )
      assert_equal(
        I18n.t("recording_studio.search.results.items", locale: :en, count: 1),
        RecordingStudio.t("recording_studio.search.results.items", count: 1)
      )
      assert_equal(
        I18n.t("recording_studio.search.results.greet", locale: :en, name: "M"),
        RecordingStudio.t("recording_studio.search.results.greet", name: "M")
      )

      assert_equal "DE Type a little",
                   RecordingStudio.t(:"recording_studio.search.results.empty.title")
      assert_equal(
        ["DE Type a little", "Name"],
        RecordingStudio.t(%w[
                            recording_studio.search.results.empty.title
                            recording_studio.search.results.columns.name
                          ])
      )
      assert_equal "DE Type a little",
                   RecordingStudio.t(:title, scope: "recording_studio.search.results.empty")

      html = RecordingStudio.t("recording_studio.search.results.html_key_html")
      assert_equal "<i>g</i>", html
      assert_predicate html, :html_safe?

      assert_equal "D", RecordingStudio.t(missing, default: "D")

      I18n.backend.store_translations(:en, {
                                        recording_studio: {
                                          search: { results: { missing_key_for_parity: "EN" } }
                                        }
                                      })
      assert_equal "EN", RecordingStudio.t(missing, default: "D")

      error = assert_raises(I18n::MissingTranslationData) do
        RecordingStudio.t("recording_studio.search.results.totally_absent", raise: true)
      end
      assert_match(/Translation missing: de\.recording_studio/, error.message)

      assert_equal "Type a little", RecordingStudio.t(key, locale: :en)
    end
  end

  def test_fallback_order_prefers_loaded_english_then_caller_default_over_shipped_table
    key = "recording_studio.search.results.empty.title"

    write_loaded_translation!(:en, key, "HOST EN Type a little")
    I18n.with_locale(:de) do
      refute I18n.exists?(key, :de)
      assert_equal "HOST EN Type a little", RecordingStudio.t(key),
                   "host :en override must win over the gem-shipped table"
    end

    delete_loaded_translation!(:en, key)
    delete_loaded_translation!(:fr, key)
    %i[en fr de].each do |locale|
      I18n.with_locale(locale) do
        assert_equal "CALLER", RecordingStudio.t(key, default: "CALLER"),
                     "caller default: must come before the gem-shipped table in #{locale}"
        assert_equal "Type a little", RecordingStudio.t(key),
                     "gem-shipped table is used last in #{locale}"
      end
    end
  ensure
    I18n.backend.store_translations(:en, gem_english_tree)
  end

  def test_html_gem_keys_escape_unsafe_interpolation_like_view_t
    # rubocop:disable-next Style/FormatStringToken
    I18n.backend.store_translations(:en, {
                                      recording_studio: {
                                        search: {
                                          probe: {
                                            hi_html: "<b>Hi %{name}</b>",
                                            greet: "Hi %{name}",
                                            items_html: {
                                              one: "<i>1 x</i>",
                                              other: "<i>%{count} xs</i>"
                                            }
                                          }
                                        }
                                      }
                                    })
    view = ActionController::Base.helpers

    I18n.with_locale(:en) do
      value = RecordingStudio.t("recording_studio.search.probe.hi_html", name: "<script>")
      assert_equal "<b>Hi &lt;script&gt;</b>", value
      assert_predicate value, :html_safe?
      assert_equal view.t("recording_studio.search.probe.hi_html", name: "<script>"), value

      plain = RecordingStudio.t("recording_studio.search.probe.greet", name: "<s>")
      assert_equal "Hi <s>", plain
      refute_predicate plain, :html_safe?
      assert_equal view.t("recording_studio.search.probe.greet", name: "<s>"), plain

      safe_arg = "<u>ok</u>".html_safe
      with_safe = RecordingStudio.t("recording_studio.search.probe.hi_html", name: safe_arg)
      assert_equal "<b>Hi <u>ok</u></b>", with_safe
      assert_equal view.t("recording_studio.search.probe.hi_html", name: safe_arg), with_safe

      plural = RecordingStudio.t("recording_studio.search.probe.items_html", count: 2)
      assert_equal "<i>2 xs</i>", plural
      assert_predicate plural, :html_safe?
      assert_equal view.t("recording_studio.search.probe.items_html", count: 2), plural

      singular = RecordingStudio.t("recording_studio.search.probe.items_html", count: 1)
      assert_equal "<i>1 x</i>", singular
      assert_predicate singular, :html_safe?
      assert_equal view.t("recording_studio.search.probe.items_html", count: 1), singular

      missing_html = "recording_studio.search.probe.missing_key_html"
      reserved = RecordingStudio.t(missing_html, default: "<b>ok</b>")
      assert_equal "<b>ok</b>", reserved
      refute_predicate reserved, :html_safe?
      assert_equal view.t(missing_html, default: "<b>ok</b>"), reserved

      # Array caller defaults on a missing _html key are marked html_safe by
      # RecordingStudio.t (String defaults stay unsafe like view t).
      array_default = RecordingStudio.t(missing_html, default: ["<b>arr</b>"])
      assert_equal "<b>arr</b>", array_default
      assert_predicate array_default, :html_safe?

      xss = RecordingStudio.t(
        "recording_studio.search.probe.hi_html",
        name: "<script>alert(1)</script>"
      )
      assert_equal "<b>Hi &lt;script&gt;alert(1)&lt;/script&gt;</b>", xss
      assert_predicate xss, :html_safe?
    end
  end

  def test_shipped_english_table_is_present_after_registration
    table = RecordingStudio::Translation.shipped_english
    refute_nil table
    refute_empty table
    assert_equal "Try a name", table.fetch("recording_studio.search.instant.placeholder")
  end

  def test_shipped_english_table_becomes_a_new_object_after_reload_reset
    before = RecordingStudio::Translation.shipped_english
    RecordingStudio::Translation.reset_shipped_english!
    after = RecordingStudio::Translation.shipped_english

    refute_same before, after
    assert_includes after.keys, "recording_studio.search.instant.placeholder"
    assert_predicate after, :frozen?
  end

  def test_missing_registered_en_yml_is_skipped_when_building_table
    missing = File.expand_path("no_such_search_en.yml", Dir.tmpdir)
    previous = RecordingStudio::Translation.send(:registered_shipped_english_paths).dup

    RecordingStudio::Translation.instance_variable_set(:@registered_shipped_english_paths, [missing])
    RecordingStudio::Translation.reset_shipped_english!
    table = RecordingStudio::Translation.shipped_english

    refute_includes table.keys, "recording_studio.search.instant.placeholder"
  ensure
    RecordingStudio::Translation.instance_variable_set(:@registered_shipped_english_paths, previous)
    RecordingStudio::Translation.reset_shipped_english!
    ensure_search_english_registered!
  end

  def test_lazy_keys_pass_through_like_i18n_t
    I18n.with_locale(:en) do
      assert_equal I18n.t(".lazy_key_without_scope"), RecordingStudio.t(".lazy_key_without_scope")
    end
  end

  def test_nil_key_does_not_raise
    I18n.with_locale(:en) do
      expected = I18n.t(nil)
      actual = RecordingStudio.t(nil)
      if expected.nil?
        assert_nil actual
      else
        assert_equal expected, actual
      end
    end
  end

  def test_global_i18n_config_snapshot_is_unchanged_by_recording_studio_t
    before = i18n_config_snapshot

    RecordingStudio.t("recording_studio.search.instant.placeholder")
    I18n.with_locale(:de) do
      RecordingStudio.t("recording_studio.search.instant.placeholder")
      RecordingStudio.t("not_a_gem_key")
    end

    assert_equal before, i18n_config_snapshot
  end

  private

  def ensure_search_english_registered!
    RecordingStudio::Translation.register_shipped_english(SEARCH_EN_YML)
    RecordingStudio::Translation.reset_shipped_english!
    RecordingStudio::Translation.shipped_english
  end

  def assert_parity(key, **options)
    expected = I18n.t(key, **options)
    actual = RecordingStudio.t(key, **options)
    assert_equal expected, actual, "parity failed for #{key.inspect} options=#{options.inspect}"
    return unless actual.is_a?(String) && key.to_s.match?(/(\b|_|\.)html\z/)

    assert_equal expected.html_safe?, actual.html_safe?
  end

  def assert_raise_parity(key, **options)
    i18n_error = assert_raises(I18n::MissingTranslationData) { I18n.t(key, **options) }
    rs_error = assert_raises(I18n::MissingTranslationData) { RecordingStudio.t(key, **options) }
    assert_equal i18n_error.message, rs_error.message
  end

  def i18n_config_snapshot
    {
      load_path: I18n.load_path.map { |path| File.expand_path(path) },
      available_locales: Array(I18n.available_locales).map(&:to_sym).sort,
      exception_handler: I18n.exception_handler,
      enforce_available_locales: I18n.enforce_available_locales
    }
  end

  def gem_english_tree
    YAML.safe_load_file(SEARCH_EN_YML, aliases: true).fetch("en")
  end

  def reset_english_backend!
    I18n.backend.store_translations(:en, gem_english_tree)
  end

  def clear_locale_translations!(locale)
    I18n.backend.send(:init_translations) unless I18n.backend.initialized?
    translations = I18n.backend.send(:translations)
    locale_key = locale.to_sym
    node = translations[locale_key]
    return unless node.is_a?(Hash)

    translations[locale_key] = node.dup if node.frozen?
    translations[locale_key].delete(:recording_studio) if translations[locale_key].is_a?(Hash)
  end

  def delete_loaded_translation!(locale, full_key)
    mutate_loaded_translation!(locale, full_key) { |node, leaf| node.delete(leaf) }
  end

  def write_loaded_translation!(locale, full_key, value)
    mutate_loaded_translation!(locale, full_key) { |node, leaf| node[leaf] = value }
  end

  # rubocop:disable-next Metrics/CyclomaticComplexity -- backend hash walk mirrors I18n nesting
  def mutate_loaded_translation!(locale, full_key)
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
    yield node, leaf if node.is_a?(Hash)
  end
end
