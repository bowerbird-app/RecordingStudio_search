# frozen_string_literal: true

module RecordingStudioSearch
  class TrigramSearcher
    def self.call(model, query, limit: nil)
      new(model, query, limit: limit).call
    end

    def initialize(model, query, limit: nil)
      @model = model
      @query = query.to_s
      @limit = limit
      @entry = Registry.entry_for(model)
    end

    def call
      relation = model.where(where_sql, query: query, threshold: threshold)
      relation = relation.order(Arel.sql(order_sql))
      limit ? relation.limit(limit) : relation
    end

    private

    attr_reader :model, :query, :limit, :entry

    def threshold
      RecordingStudioSearch.configuration.trigram_threshold
    end

    def table
      model.quoted_table_name
    end

    def against
      Array(entry&.against)
    end

    def quoted_against
      against.map { |column| "#{table}.#{model.connection.quote_column_name(column)}" }
    end

    def where_sql
      trigram = quoted_against.map do |column|
        "similarity(coalesce(#{column}::text, ''), :query) >= :threshold"
      end.join(" OR ")

      <<~SQL.squish
        #{table}.search_vector @@ plainto_tsquery('english', :query)
        OR (#{trigram.presence || 'FALSE'})
      SQL
    end

    def order_sql
      quoted_query = model.connection.quote(query)
      similarities = against.zip(quoted_against).map do |column, quoted|
        scale = Schema::RANK_SCALE[entry&.weights&.[](column)]
        similarity = "similarity(coalesce(#{quoted}::text, ''), #{quoted_query})"
        scale ? "(#{similarity} * #{scale})" : similarity
      end
      greatest = similarities.any? ? "GREATEST(#{similarities.join(', ')})" : "0"

      <<~SQL.squish
        ts_rank(#{table}.search_vector, plainto_tsquery('english', #{quoted_query})) DESC,
        #{greatest} DESC
      SQL
    end
  end
end
