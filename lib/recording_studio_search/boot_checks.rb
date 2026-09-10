# frozen_string_literal: true

module RecordingStudioSearch
  class BootChecks
    def self.run
      new.run
    end

    def run
      warn_missing_embeddings
      warn_schema_mismatch
    end

    private

    def warn_missing_embeddings
      return if Registry.pgvector_entries.empty?
      return if EmbeddingAdapter.new.available?
      return if RecordingStudioSearch.configuration.instance_variable_get(:@missing_embeddings_warned)

      RecordingStudioSearch.configuration.instance_variable_set(:@missing_embeddings_warned, true)
      Rails.logger.warn(
        "[recording_studio_search] pgvector models are registered but no embedding client " \
        "or RecordingStudioAI embeddings API is available; treating them as trigram until fixed"
      )
    end

    def warn_schema_mismatch
      return unless defined?(ActiveRecord::Base)
      return unless ActiveRecord::Base.connected?

      Registry.entries.each_value do |entry|
        model = entry.model
        next unless model.table_exists?

        unless model.column_names.include?("search_vector")
          Rails.logger.warn(
            "[recording_studio_search] #{model.name} is searchable but #{model.table_name} " \
            "has no search_vector column; run the searchable_pg_trgm generator"
          )
        end

        next unless entry.backend == :pgvector
        next unless defined?(Document) && Document.table_exists?

        next unless model.column_names.intersect?(%w[embedding embedding_at embedding_model])

        Rails.logger.warn(
          "[recording_studio_search] #{model.name} has embedding columns on the model table; " \
          "embeddings belong on recording_studio_search_documents"
        )
      end
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
      nil
    end
  end
end
