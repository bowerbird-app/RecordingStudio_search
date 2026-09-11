# frozen_string_literal: true

RecordingStudioSearch.configure do |config|
  config.default_backend = :pg_trgm
  config.embedding_provider = :openai
  config.embedding_model = "text-embedding-3-small"
  config.embedding_dimensions = 1536
  config.embedding_distance = :cosine
  config.embedding_client = nil
  config.trigram_threshold = 0.3
  config.vector_result_limit = 50
end
