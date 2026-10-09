# frozen_string_literal: true

require "test_helper"
require "i18n"
require "action_view"
require_relative "../app/helpers/recording_studio_search/instant_search_helper"

class InstantSearchHelperI18nTest < Minitest::Test
  class FakeView
    include ActionView::Helpers::TagHelper
    include ActionView::Context

    attr_reader :rendered

    def initialize
      @rendered = nil
      @output_buffer = ActionView::OutputBuffer.new
    end

    def t(key, **)
      I18n.t(key, **)
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
  end

  def teardown
    I18n.load_path.replace(@original_load_path)
    I18n.backend.reload!
  end

  def test_instant_search_field_default_placeholder_is_english_try_a_name
    stub_flatpack_search!
    view = FakeView.new
    helper = RecordingStudioSearch::InstantSearchHelper.new(view, routes_stub)

    I18n.with_locale(:en) do
      helper.instant_search_field(models: ["User"], frame_id: "people_results")
    end

    assert_equal "Try a name", view.rendered.placeholder
  end

  def test_instant_search_field_keeps_caller_placeholder
    stub_flatpack_search!
    view = FakeView.new
    helper = RecordingStudioSearch::InstantSearchHelper.new(view, routes_stub)

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

  def stub_flatpack_search!
    return if defined?(FlatPack::Search::Component)

    component = Class.new do
      attr_reader :name, :value, :placeholder, :max_width, :size

      def initialize(name:, value:, placeholder:, max_width:, size:)
        @name = name
        @value = value
        @placeholder = placeholder
        @max_width = max_width
        @size = size
      end
    end
    search_module = Module.new
    search_module.const_set(:Component, component)
    flat_pack = Module.new
    flat_pack.const_set(:Search, search_module)
    Object.const_set(:FlatPack, flat_pack) unless defined?(FlatPack)
  end

  def routes_stub
    Object.new.tap do |routes|
      def routes.instant_search_path(**)
        "/recording_studio_search/instant_search"
      end
    end
  end
end
