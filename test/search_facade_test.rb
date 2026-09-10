# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class SearchFacadeTest < Minitest::Test
  def fake_search
    lambda do |model, query, limit: nil|
      { model: model, query: query, limit: limit }
    end
  end

  def test_single_model_returns_the_searcher_result
    model = Class.new
    RecordingStudioSearch::Searcher.stub(:call, fake_search) do
      result = RecordingStudioSearch.search(model, "ada", limit: 10)

      assert_equal({ model: model, query: "ada", limit: 10 }, result)
    end
  end

  def test_array_returns_hash_of_per_model_results_in_order
    first = Class.new
    second = Class.new
    RecordingStudioSearch::Searcher.stub(:call, fake_search) do
      result = RecordingStudioSearch.search([first, second], "refund", limit: 20)

      assert_equal [first, second], result.keys
      assert_equal({ model: first, query: "refund", limit: 20 }, result[first])
      assert_equal({ model: second, query: "refund", limit: 20 }, result[second])
    end
  end

  def test_array_skips_duplicate_models
    model = Class.new
    RecordingStudioSearch::Searcher.stub(:call, fake_search) do
      result = RecordingStudioSearch.search([model, model], "q")

      assert_equal [model], result.keys
    end
  end
end
