# frozen_string_literal: true

require "test_helper"

class ResultFiltersTest < Minitest::Test
  Article = Class.new

  def setup
    RecordingStudioSearch.reset_result_filters!
  end

  def teardown
    RecordingStudioSearch.reset_result_filters!
  end

  def test_the_same_source_line_does_not_stack_on_reload
    2.times { register_article_filter }

    assert_equal 1, RecordingStudioSearch::ResultFilters.count_for(Article)
  end

  def test_a_different_source_line_is_a_second_filter
    register_article_filter
    RecordingStudioSearch.register_result_filter(Article) { |relation| relation }

    assert_equal 2, RecordingStudioSearch::ResultFilters.count_for(Article)
  end

  def test_reset_clears_filters
    register_article_filter
    RecordingStudioSearch.reset_result_filters!

    assert_equal 0, RecordingStudioSearch::ResultFilters.count_for(Article)
    refute RecordingStudioSearch::ResultFilters.registered_for?(Article)
  end

  def test_register_requires_a_named_class_and_a_block
    error = assert_raises(ArgumentError) do
      RecordingStudioSearch.register_result_filter("Article") { |relation| relation }
    end
    assert_match(/model class/, error.message)

    assert_raises(ArgumentError) { RecordingStudioSearch.register_result_filter(Article) }

    anonymous = Class.new
    assert_raises(ArgumentError) do
      RecordingStudioSearch.register_result_filter(anonymous) { |relation| relation }
    end
  end

  def test_engine_exposes_view_helpers_without_a_routes_proxy
    root = File.expand_path("..", __dir__)
    engine = File.read(File.join(root, "lib/recording_studio_search/engine.rb"))
    helper = File.read(File.join(root, "app/helpers/recording_studio_search/application_helper.rb"))

    refute_includes engine, "RoutesProxy"
    assert_includes helper, "InstantSearchHelper"
    refute File.exist?(File.join(root, "lib/recording_studio_search/routes_proxy.rb"))
  end

  private

  def register_article_filter
    RecordingStudioSearch.register_result_filter(Article) { |relation| relation }
  end
end
