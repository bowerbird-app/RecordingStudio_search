# frozen_string_literal: true

module RecordingStudioSearch
  class EmbeddingAdapter
    class Error < StandardError; end

    def initialize(configuration: RecordingStudioSearch.configuration)
      @configuration = configuration
    end

    def available?
      configuration.embedding_client.present? || recording_studio_ai_embeddings?
    end

    def embed(text:)
      raise Error, "blank text" if text.to_s.strip.empty?

      values = Array(invoke(text)).map { |value| Float(value) }
      raise Error, "blank embedding" if values.empty?

      values
    rescue ArgumentError, TypeError => e
      raise Error, e.message
    end

    private

    attr_reader :configuration

    def invoke(text)
      if configuration.embedding_client
        return configuration.embedding_client.call(
          text: text,
          model: configuration.embedding_model
        )
      end

      raise Error, "no embedding client or RecordingStudioAI embeddings API" unless recording_studio_ai_embeddings?

      unwrap(
        RecordingStudioAI::Embeddings.create!(
          text: text,
          model: configuration.embedding_model,
          provider: configuration.embedding_provider
        )
      )
    end

    def unwrap(result)
      return result[:embedding] if result.is_a?(Hash) && result.key?(:embedding)
      return result["embedding"] if result.is_a?(Hash) && result.key?("embedding")

      result
    end

    def recording_studio_ai_embeddings?
      defined?(RecordingStudioAI::Embeddings) &&
        RecordingStudioAI::Embeddings.respond_to?(:create!)
    end
  end
end
