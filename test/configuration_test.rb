# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioSearch::Configuration.new
  end

  def test_defaults
    assert_equal :pg_trgm, @configuration.default_backend
    assert_equal :openai, @configuration.embedding_provider
    assert_equal "text-embedding-3-small", @configuration.embedding_model
    assert_equal 1536, @configuration.embedding_dimensions
    assert_equal :cosine, @configuration.embedding_distance
    assert_nil @configuration.embedding_client
    assert_in_delta 0.3, @configuration.trigram_threshold
    assert_equal 50, @configuration.vector_result_limit
    assert_instance_of RecordingStudio::Hooks, @configuration.hooks
  end

  def test_merge_updates_known_attributes
    client = ->(_text:, _model:) { [0.1] }
    @configuration.merge!(
      default_backend: :pgvector,
      embedding_model: "custom-model",
      embedding_dimensions: 8,
      embedding_client: client,
      trigram_threshold: 0.5,
      vector_result_limit: 9
    )

    assert_equal :pgvector, @configuration.default_backend
    assert_equal "custom-model", @configuration.embedding_model
    assert_equal 8, @configuration.embedding_dimensions
    assert_equal client, @configuration.embedding_client
    assert_in_delta 0.5, @configuration.trigram_threshold
    assert_equal 9, @configuration.vector_result_limit
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", trigram_threshold: 0.7)

    refute_respond_to @configuration, :unknown_key
    assert_in_delta 0.7, @configuration.trigram_threshold
  end

  def test_merge_with_non_enumerable_is_noop
    original = @configuration.to_h

    @configuration.merge!(nil)

    assert_equal original[:default_backend], @configuration.default_backend
    assert_equal original[:trigram_threshold], @configuration.trigram_threshold
    assert_equal original[:vector_result_limit], @configuration.vector_result_limit
  end

  def test_merge_accepts_string_keys
    @configuration.merge!("embedding_model" => "string-model", "vector_result_limit" => 12)

    assert_equal "string-model", @configuration.embedding_model
    assert_equal 12, @configuration.vector_result_limit
  end

  def test_to_h_reports_registered_hook_counts
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.after_service { nil }

    result = @configuration.to_h

    assert_equal false, result.fetch(:embedding_client)
    assert_equal 2, result.fetch(:hooks_registered).fetch(:before_initialize)
    assert_equal 1, result.fetch(:hooks_registered).fetch(:after_service)
  end

  def test_configure_without_block_is_safe
    RecordingStudioSearch.configure

    assert_kind_of RecordingStudioSearch::Configuration, RecordingStudioSearch.configuration
  end
end
