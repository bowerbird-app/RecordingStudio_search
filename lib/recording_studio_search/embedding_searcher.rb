# frozen_string_literal: true

module RecordingStudioSearch
  class EmbeddingSearcher
    DISTANCE_OPERATORS = { l2: "<->", inner_product: "<#>", cosine: "<=>" }.freeze

    def self.call(model, query, limit: nil, root_recording_id: nil, recording_ids: nil)
      new(model, query, limit: limit, root_recording_id: root_recording_id, recording_ids: recording_ids).call
    end

    def initialize(model, query, limit: nil, root_recording_id: nil, recording_ids: nil)
      @model = model
      @query = query.to_s
      @limit = limit || RecordingStudioSearch.configuration.vector_result_limit
      @entry = Registry.entry_for(model)
      @adapter = EmbeddingAdapter.new
      @root_recording_ids = Array(root_recording_id).filter_map(&:presence)
      @recording_ids = recording_ids
    end

    def call
      vector = cached_or_create_query_embedding
      ids = nearest_ids(vector)
      if ids.empty?
        warn_fallback("cold start / no documents")
        return TrigramSearcher.call(model, query, limit: limit)
      end

      model.where(id: ids).order(order_for(ids)).limit(limit)
    rescue EmbeddingAdapter::Error => e
      warn_fallback("#{e.class}: #{e.message}")
      TrigramSearcher.call(model, query, limit: limit)
    end

    private

    attr_reader :model, :query, :limit, :entry, :adapter, :root_recording_ids, :recording_ids

    def cached_or_create_query_embedding
      keyword = Normalize.keyword(query)
      model_name = RecordingStudioSearch.configuration.embedding_model
      cached = Query.find_by(keyword: keyword, embedding_model: model_name)
      if cached
        cached.increment!(:hit_count)
        return cached.embedding
      end

      vector = adapter.embed(text: query)
      Query.create!(
        keyword: keyword,
        embedding: vector,
        embedding_model: model_name,
        embedding_at: Time.current,
        hit_count: 0
      )
      vector
    end

    def nearest_ids(vector)
      connection = Document.connection
      connection.transaction do
        iterative = VectorScan.iterative?(connection)
        VectorScan.apply!(connection, iterative: iterative)
        ids = nearest_scope(vector).limit(limit).pluck(:searchable_id)
        VectorScan.restore!(connection, iterative: iterative)
        ids
      end
    end

    def nearest_scope(vector)
      scope = Document.where(searchable_type: Registry.model_class(model).name).where.not(embedding: nil)
      scope = scope.where.not(recording_id: nil) if entry&.recording_id_method
      scope = scope.where(recording_id: recording_ids) unless recording_ids.nil?
      scope = restrict_to_tenant(scope)
      scope.order(distance_order(vector))
    end

    def restrict_to_tenant(scope)
      return scope.where(root_recording_id: root_recording_ids) if root_recording_ids.any?
      return scope unless scoped_relation?
      return scope.none unless defined?(RecordingStudio::Recording)

      roots = RecordingStudio::Recording
              .where(recordable_type: Registry.model_class(model).name)
              .where(recordable_id: scoped_record_ids)
              .where.not(root_recording_id: nil)
              .select(:root_recording_id)
      scope.where(root_recording_id: roots)
    end

    def scoped_relation?
      model.is_a?(ActiveRecord::Relation) && !model.where_clause.empty?
    end

    def scoped_record_ids
      model.except(:order, :includes, :preload, :eager_load, :limit, :offset).reselect(:id)
    end

    def distance_order(vector)
      Arel.sql("embedding #{distance_operator} ?::vector", Normalize.vector_literal(vector))
    end

    def order_for(ids)
      placeholders = Array.new(ids.size, "?").join(", ")
      Arel.sql(
        "array_position(ARRAY[#{placeholders}]::uuid[], #{model.quoted_table_name}.id::uuid)",
        *ids
      )
    end

    def distance_operator
      DISTANCE_OPERATORS.fetch(RecordingStudioSearch.configuration.embedding_distance.to_sym, "<=>")
    end

    def warn_fallback(reason)
      Rails.logger.warn(
        "[recording_studio_search] vector search falling back to trigram " \
        "model=#{Registry.model_class(model).name} query_digest=#{Normalize.digest(query)} #{reason}"
      )
    end
  end
end
