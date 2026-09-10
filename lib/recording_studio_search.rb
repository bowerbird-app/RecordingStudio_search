# frozen_string_literal: true

require "recording_studio"
require "pgvector"
require "digest"
require "recording_studio_search/version"
require "recording_studio_search/configuration"
require "recording_studio_search/normalize"
require "recording_studio_search/schema"
require "recording_studio_search/registry"
require "recording_studio_search/embedding_adapter"
require "recording_studio_search/trigram_searcher"
require "recording_studio_search/embedding_searcher"
require "recording_studio_search/searcher"
require "recording_studio_search/searchable"
require "recording_studio_search/document_embedder"
require "recording_studio_search/boot_checks"
require "recording_studio_search/capabilities/example"
require "recording_studio_search/engine"

module RecordingStudioSearch
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def search(model, query, limit: nil)
      Searcher.call(model, query, limit: limit)
    end

    def embed_later(record, recording_id: nil)
      RecordingStudioSearch::EmbedDocumentJob.perform_later(
        searchable_type: record.class.name,
        searchable_id: record.id.to_s,
        recording_id: (recording_id.presence || recording_id_for(record))&.to_s
      )
    end

    def recording_id_for(record)
      method_name = Registry.entry_for(record.class)&.recording_id_method
      return unless method_name && record.respond_to?(method_name)

      record.public_send(method_name)
    end

    def effective_backend_for(model)
      entry = Registry.entry_for(model)
      backend = entry&.backend || configuration.default_backend
      return :pg_trgm if backend == :pgvector && !EmbeddingAdapter.new.available?

      backend
    end
  end
end
