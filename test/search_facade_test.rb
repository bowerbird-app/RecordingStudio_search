# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class SearchFacadeTest < Minitest::Test
  def fake_search
    lambda do |model, query, limit: nil, access: RecordingStudioSearch::Access.new|
      { model: model, query: query, limit: limit, access: access }
    end
  end

  def test_single_model_returns_the_searcher_result
    model = Class.new
    RecordingStudioSearch::Searcher.stub(:call, fake_search) do
      result = RecordingStudioSearch.search(model, "ada", limit: 10, unscoped: true)

      assert_equal model, result.fetch(:model)
      assert_equal "ada", result.fetch(:query)
      assert_equal 10, result.fetch(:limit)
      assert_equal true, result.fetch(:access).unscoped
    end
  end

  def test_array_returns_hash_of_per_model_results_in_order
    first = Class.new
    second = Class.new
    actor = Object.new
    root = Object.new
    RecordingStudioSearch::Searcher.stub(:call, fake_search) do
      result = RecordingStudioSearch.search([first, second], "refund", actor: actor, root: root, limit: 20)

      assert_equal [first, second], result.keys
      assert_equal actor, result[first].fetch(:access).actor
      assert_equal root, result[first].fetch(:access).root
      assert_equal 20, result[first].fetch(:limit)
      assert_equal result[first].fetch(:access), result[second].fetch(:access)
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
