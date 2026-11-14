# frozen_string_literal: true

module RecordingStudioSearch
  class Searcher
    def self.call(model, query, limit: nil, access: Access.new)
      new(model, query, limit: limit, access: access).call
    end

    def initialize(model, query, limit: nil, access: Access.new)
      @model = model
      @query = query
      @limit = limit
      @access = access
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

    attr_reader :model, :query, :limit, :access

    def perform
      relation = scoped_relation
      return relation if query.to_s.strip.empty?

      case backend
      when :pgvector
        EmbeddingSearcher.call(
          relation,
          query,
          limit: limit,
          root_recording_id: access.vector_root_id,
          recording_ids: recording_ids
        )
      else
        TrigramSearcher.call(relation, query, limit: limit)
      end
    end

    def scoped_relation
      base = model.respond_to?(:all) ? model.all : model
      return base if access.unscoped?

      require_access_scope!
      AccessibleScope.relation_for(base, access.actor, root: access.root)
    end

    def require_access_scope!
      return if access.actor.present? && access.root.present?

      raise ArgumentError, "Pass actor: and root: to scope search, or unscoped: true to search without access."
    end

    def recording_ids
      return if access.unscoped?

      AccessibleScope.recording_ids_for(
        access.actor,
        root: access.root,
        recordable_type: Registry.model_class(model).name
      )
    end

    def backend
      RecordingStudioSearch.effective_backend_for(model)
    end
  end
end
