# frozen_string_literal: true

require "test_helper"

class EmbeddingAdapterTest < Minitest::Test
  def teardown
    RecordingStudioSearch.reset_configuration!
  end

  def test_uses_injected_client
    RecordingStudioSearch.configure do |config|
      config.embedding_client = ->(text:, model:) { [text.length, model.length] }
    end

    vector = RecordingStudioSearch::EmbeddingAdapter.new.embed(text: "hi")
    assert_equal [2.0, RecordingStudioSearch.configuration.embedding_model.length.to_f], vector
  end

  def test_blank_text_raises
    RecordingStudioSearch.configure do |config|
      config.embedding_client = ->(_text:, _model:) { [1.0] }
    end

    assert_raises(RecordingStudioSearch::EmbeddingAdapter::Error) do
      RecordingStudioSearch::EmbeddingAdapter.new.embed(text: "  ")
    end
  end

  def test_blank_client_result_raises
    RecordingStudioSearch.configure do |config|
      config.embedding_client = ->(_text:, _model:) { [] }
    end

    assert_raises(RecordingStudioSearch::EmbeddingAdapter::Error) do
      RecordingStudioSearch::EmbeddingAdapter.new.embed(text: "hello")
    end
  end

  def test_available_without_client_or_ai
    RecordingStudioSearch.reset_configuration!
    refute RecordingStudioSearch::EmbeddingAdapter.new.available?
  end
end
