# frozen_string_literal: true

require "test_helper"
require "i18n"
require "action_view"
require_relative "../app/helpers/recording_studio_search/instant_search_helper"

class InstantSearchHelperI18nTest < Minitest::Test
  class SearchControl
    attr_reader :name, :value, :placeholder, :max_width, :size

    def initialize(name:, value:, placeholder:, max_width:, size:)
      @name = name
      @value = value
      @placeholder = placeholder
      @max_width = max_width
      @size = size
    end
  end

  class FakeView
    include ActionView::Helpers::TagHelper
    include ActionView::Context

    attr_reader :rendered

    def initialize
      @rendered = nil
      @output_buffer = ActionView::OutputBuffer.new
    end

    def render(component)
      @rendered = component
      "search-control"
    end
  end

  def setup
    @locale_path = File.expand_path("../config/locales/en.yml", __dir__)
    @original_load_path = I18n.load_path.dup
    I18n.load_path |= [@locale_path]
    I18n.backend.reload!
    RecordingStudio::Translation.register_shipped_english(@locale_path)
    RecordingStudio::Translation.reset_shipped_english!
  end

  def teardown
    I18n.load_path.replace(@original_load_path)
    I18n.backend.reload!
  end

  def test_instant_search_field_default_placeholder_is_english_try_a_name
    view = FakeView.new
    helper = helper_for(view)

    I18n.with_locale(:en) do
      helper.instant_search_field(models: ["User"], frame_id: "people_results")
    end

    assert_equal "Try a name", view.rendered.placeholder
  end

  def test_instant_search_field_placeholder_falls_back_to_shipped_english_without_locale_key
    view = FakeView.new
    helper = helper_for(view)
    original_available = I18n.available_locales
    I18n.backend = I18n::Backend::Simple.new
    I18n.load_path = []
    I18n.backend.load_translations
    I18n.available_locales = %i[en zz]
    RecordingStudio::Translation.reset_shipped_english!

    I18n.with_locale(:zz) do
      helper.instant_search_field(models: ["User"], frame_id: "people_results")
    end

    assert_equal "Try a name", view.rendered.placeholder
  ensure
    I18n.available_locales = original_available if original_available
    I18n.load_path |= [@locale_path]
    I18n.backend.reload!
    RecordingStudio::Translation.reset_shipped_english!
  end

  def test_instant_search_field_keeps_caller_placeholder
    view = FakeView.new
    helper = helper_for(view)

    I18n.with_locale(:en) do
      helper.instant_search_field(
        models: ["User"],
        frame_id: "people_results",
        placeholder: "Try Ada or hopper"
      )
    end

    assert_equal "Try Ada or hopper", view.rendered.placeholder
  end

  private

  def helper_for(view)
    RecordingStudioSearch::InstantSearchHelper.new(
      view,
      routes_stub,
      search_component_class: SearchControl
    )
  end

  def routes_stub
    Object.new.tap do |routes|
      def routes.instant_search_path(**)
        "/recording_studio_search/instant_search"
      end
    end
  end
end
