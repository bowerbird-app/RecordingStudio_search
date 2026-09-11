# frozen_string_literal: true

module RecordingStudioSearch
  class EmbeddingSearcher
    def self.call(model, query, limit: nil)
      new(model, query, limit: limit).call
    end

    def initialize(model, query, limit: nil)
      @model = model
      @query = query.to_s
      @limit = limit || RecordingStudioSearch.configuration.vector_result_limit
      @entry = Registry.entry_for(model)
      @adapter = EmbeddingAdapter.new
    end

    def call
      vector = cached_or_create_query_embedding
      ids = nearest_ids(vector)
      if ids.empty?
        warn_fallback("cold start / no documents")
        return TrigramSearcher.call(model, query, limit: limit)
      end

      model.where(id: ids).order(Arel.sql(order_for(ids))).limit(limit)
    rescue EmbeddingAdapter::Error => e
      warn_fallback("#{e.class}: #{e.message}")
      TrigramSearcher.call(model, query, limit: limit)
    end

    private

    attr_reader :model, :query, :limit, :entry, :adapter

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
      literal = Document.connection.quote(Normalize.vector_literal(vector))
      scope = Document.where(searchable_type: Registry.model_class(model).name).where.not(embedding: nil)
      scope = scope.where.not(recording_id: nil) if entry&.recording_id_method
      scope.order(Arel.sql("embedding #{distance_operator} #{literal}::vector"))
           .limit(limit)
           .pluck(:searchable_id)
    end

    def order_for(ids)
      quoted = ids.map { |id| model.connection.quote(id) }.join(", ")
      "array_position(ARRAY[#{quoted}]::uuid[], #{model.quoted_table_name}.id::uuid)"
    end

    def distance_operator
      case RecordingStudioSearch.configuration.embedding_distance.to_sym
      when :l2 then "<->"
      when :inner_product then "<#>"
      else "<=>"
      end
    end

    def warn_fallback(reason)
      Rails.logger.warn(
        "[recording_studio_search] vector search falling back to trigram " \
        "model=#{Registry.model_class(model).name} query_digest=#{Normalize.digest(query)} #{reason}"
      )
    end
  end
end
