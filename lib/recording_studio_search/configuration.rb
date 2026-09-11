# frozen_string_literal: true

module RecordingStudioSearch
  class Configuration
    BACKENDS = %i[pg_trgm pgvector].freeze
    DISTANCES = %i[cosine l2 inner_product].freeze

    attr_accessor :default_backend,
                  :embedding_provider,
                  :embedding_model,
                  :embedding_dimensions,
                  :embedding_distance,
                  :embedding_client,
                  :trigram_threshold,
                  :vector_result_limit
    attr_reader :hooks

    def initialize
      @default_backend = :pg_trgm
      @embedding_provider = :openai
      @embedding_model = "text-embedding-3-small"
      @embedding_dimensions = 1536
      @embedding_distance = :cosine
      @embedding_client = nil
      @trigram_threshold = 0.3
      @vector_result_limit = 50
      @hooks = RecordingStudio::Hooks.new
    end

    def to_h
      {
        default_backend: default_backend,
        embedding_provider: embedding_provider,
        embedding_model: embedding_model,
        embedding_dimensions: embedding_dimensions,
        embedding_distance: embedding_distance,
        embedding_client: embedding_client.present?,
        trigram_threshold: trigram_threshold,
        vector_result_limit: vector_result_limit,
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |key, value|
        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
      end
    end
  end
end
