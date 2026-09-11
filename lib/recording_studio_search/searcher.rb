# frozen_string_literal: true

module RecordingStudioSearch
  class Searcher
    def self.call(model, query, limit: nil)
      new(model, query, limit: limit).call
    end

    def initialize(model, query, limit: nil)
      @model = model
      @query = query
      @limit = limit
    end

    def call
      ActiveSupport::Notifications.instrument(
        "search.recording_studio_search",
        model: Registry.model_class(model).name,
        backend: backend,
        query_digest: Normalize.digest(query.to_s)
      ) { perform }
    end

    private

    attr_reader :model, :query, :limit

    def perform
      return model.all if query.to_s.strip.empty?

      case backend
      when :pgvector
        EmbeddingSearcher.call(model, query, limit: limit)
      else
        TrigramSearcher.call(model, query, limit: limit)
      end
    end

    def backend
      RecordingStudioSearch.effective_backend_for(model)
    end
  end
end
