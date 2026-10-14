# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

# Real-page English fallback for instant-search chrome when a locale lacks
# translations or when loaded :en keys are deleted. Uses :de so boot-loaded
# host English overrides and dummy :fr do not interfere.
class EnglishFallbackTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  EMPTY_TITLE_KEY = "recording_studio.search.results.empty.title"
  PLACEHOLDER_KEY = "recording_studio.search.instant.placeholder"

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
      account.name = "Ada Admin"
    end
    @user.update!(name: "Ada Admin")
    sign_in @user
    @previous_locales = I18n.available_locales
    I18n.available_locales = (@previous_locales + %i[en de fr]).uniq
    I18n.t(EMPTY_TITLE_KEY)
  end

  teardown do
    I18n.locale = I18n.default_locale
    I18n.available_locales = @previous_locales if @previous_locales
  end

  test "missing locale without translations renders gem english on instant page" do
    I18n.with_locale(:de) do
      refute locale_has_own_translation?(:de, EMPTY_TITLE_KEY),
             ":de must not ship its own empty.title"

      get instant_people_path

      assert_response :success
      assert_select "h1", text: /As you type/
      assert_includes @response.body, "Type a little"
      assert_includes @response.body, "Hits land here as you go."
      refute_search_translation_missing!(@response.body)
    end
  end

  test "english render matches gem english strings from main" do
    I18n.with_locale(:en) do
      get instant_people_path

      assert_response :success
      assert_select "h1", text: /As you type/
      assert_includes @response.body, "Type a little"
      assert_includes @response.body, "Hits land here as you go."
      assert_includes @response.body, "Try Ada or hopper"
      refute_search_translation_missing!(@response.body)
    end
  end

  test "deleted english key on instant page shows shipped Type a little without translation missing" do
    delete_loaded_translation!(:en, EMPTY_TITLE_KEY)
    delete_loaded_translation!(:fr, EMPTY_TITLE_KEY)

    refute I18n.exists?(EMPTY_TITLE_KEY, :en)
    refute I18n.exists?(EMPTY_TITLE_KEY, :fr)

    previous_raise = ActionView::Helpers::TranslationHelper.raise_on_missing_translations

    [false, true].each do |raise_on_missing|
      ActionView::Helpers::TranslationHelper.raise_on_missing_translations = raise_on_missing

      %i[en fr].each do |locale|
        I18n.with_locale(locale) do
          get instant_people_path

          assert_response :success
          assert_select "h1", text: /As you type/
          assert_includes @response.body, "Type a little"
          refute_search_translation_missing!(@response.body)
        end
      end
    end
  ensure
    ActionView::Helpers::TranslationHelper.raise_on_missing_translations = previous_raise
    I18n.reload!
  end

  test "search en.yml path is registered at boot without calling the initializer" do
    expected = File.expand_path(RecordingStudioSearch::Engine.root.join("config/locales/en.yml"))
    paths = RecordingStudio::Translation.send(:registered_shipped_english_paths)

    assert_includes paths, expected,
                    "engine boot must register this gem's en.yml; do not call the initializer in the test"
    assert_equal "Try a name",
                 RecordingStudio::Translation.shipped_english.fetch(PLACEHOLDER_KEY)
    assert_equal "Type a little",
                 RecordingStudio::Translation.shipped_english.fetch(EMPTY_TITLE_KEY)
  end

  test "search en.yml path stays registered after rails reloader reload" do
    expected = File.expand_path(RecordingStudioSearch::Engine.root.join("config/locales/en.yml"))
    before_paths = RecordingStudio::Translation.send(:registered_shipped_english_paths).dup
    assert_includes before_paths, expected

    previous_cache_classes = Rails.application.config.cache_classes
    Rails.application.config.cache_classes = false
    RecordingStudioMetrics.registry.reset! if defined?(RecordingStudioMetrics)

    Rails.application.reloader.reload!

    after_paths = RecordingStudio::Translation.send(:registered_shipped_english_paths)
    assert_includes after_paths, expected
    assert_equal "Try a name",
                 RecordingStudio::Translation.shipped_english.fetch(PLACEHOLDER_KEY)
    assert_equal "Type a little",
                 RecordingStudio::Translation.shipped_english.fetch(EMPTY_TITLE_KEY)
  ensure
    Rails.application.config.cache_classes = previous_cache_classes unless previous_cache_classes.nil?
  end

  test "global I18n config keeps fallbacks load_path available_locales and exception handler" do
    snapshot = i18n_config_snapshot
    gem_en = File.expand_path(RecordingStudioSearch::Engine.root.join("config/locales/en.yml"))
    boot_en = Rails.root.join("config/locales/recording_studio_search_host.en.yml").to_s

    assert_includes snapshot.fetch(:load_path), File.expand_path(gem_en)
    assert_includes snapshot.fetch(:load_path), File.expand_path(boot_en)
    assert_operator snapshot.fetch(:load_path).index(File.expand_path(gem_en)),
                    :<,
                    snapshot.fetch(:load_path).index(File.expand_path(boot_en))
    assert snapshot.fetch(:exception_handler), "expected an I18n exception handler"
    assert_includes snapshot.fetch(:available_locales), :en
  end

  private

  # Flatpack chrome may still say "Translation missing: <locale>.flatpack.*";
  # this gem only owns recording_studio.search.*.
  def refute_search_translation_missing!(body)
    refute_match(/translation missing: [a-z]+\.recording_studio\.search/i, body)
    assert_includes body, "Type a little"
  end

  def i18n_config_snapshot
    {
      load_path: I18n.load_path.map { |path| File.expand_path(path) },
      available_locales: Array(I18n.available_locales).map(&:to_sym).sort,
      exception_handler: I18n.exception_handler,
      enforce_available_locales: I18n.enforce_available_locales,
      fallbacks_class: (I18n.fallbacks.class.name if I18n.respond_to?(:fallbacks))
    }
  end

  def locale_has_own_translation?(locale, full_key)
    I18n.backend.send(:init_translations) unless I18n.backend.initialized?
    node = I18n.backend.send(:translations)[locale.to_sym]
    return false unless node.is_a?(Hash)

    full_key.split(".").map(&:to_sym).each do |part|
      return false unless node.is_a?(Hash) && node.key?(part)

      node = node[part]
    end
    !node.nil?
  end

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
