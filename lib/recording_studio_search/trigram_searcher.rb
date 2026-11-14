# frozen_string_literal: true

module RecordingStudioSearch
  class TrigramSearcher
    THRESHOLD_NOTE = /\Apg_trgm\.similarity_threshold=(\d+\.\d{6})\z/

    def self.call(model, query, limit: nil)
      new(model, query, limit: limit).call
    end

    # pg_trgm reads this GUC for the % operator. Keep the literal numeric so it
    # can be quoted into SET LOCAL and into the SQL comment that keys the query cache.
    def self.threshold_literal(threshold)
      number = Float(threshold)
      unless number.finite? && number.between?(0.0, 1.0)
        raise ArgumentError, "trigram_threshold must be between 0 and 1"
      end

      format("%.6f", number)
    end

    def initialize(model, query, limit: nil)
      @model = model
      @query = query.to_s
      @limit = limit
      @entry = Registry.entry_for(model)
    end

    def call
      relation = model.where(where_sql, query: query)
      relation = relation.order(Arel.sql(order_sql))
      relation = relation.limit(limit) if limit
      relation
        .annotate("pg_trgm.similarity_threshold=#{threshold_literal}")
        .extending(Thresholded)
    end

    private

    attr_reader :model, :query, :limit, :entry

    def threshold_literal
      self.class.threshold_literal(RecordingStudioSearch.configuration.trigram_threshold)
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
      clauses = quoted_against.map { |column| "(#{column} % (:query)::text)" }
      clauses << "(#{table}.search_vector @@ plainto_tsquery('english', :query))"
      clauses.join(" OR ")
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

    # Applies pg_trgm.similarity_threshold when the relation actually runs.
    # Callers can keep chaining where/limit; the GUC is set for that statement
    # and restored afterwards, including when this joins an open transaction.
    module Thresholded
      def calculate(...)
        with_similarity_threshold { super }
      end

      def pluck(...)
        with_similarity_threshold { super }
      end

      def exists?(...)
        with_similarity_threshold { super }
      end

      def ids
        with_similarity_threshold { super }
      end

      def update_all(...)
        with_similarity_threshold { super }
      end

      def delete_all(...)
        with_similarity_threshold { super }
      end

      private

      def exec_queries(...)
        with_similarity_threshold { super }
      end

      def with_similarity_threshold
        transaction(requires_new: true) do
          # pg_trgm registers its GUCs when the library loads, which is the first
          # use in the session. This read does that before SHOW / SET LOCAL.
          connection.select_value("SELECT similarity('', '')")
          previous = connection.select_value("SHOW pg_trgm.similarity_threshold")
          assign_similarity_threshold(similarity_threshold)
          begin
            yield
          ensure
            assign_similarity_threshold(previous) unless connection.current_transaction.state.invalidated?
          end
        end
      end

      def similarity_threshold
        note = annotate_values.find { |value| value.is_a?(String) && value.match?(THRESHOLD_NOTE) }
        return note[THRESHOLD_NOTE, 1] if note

        TrigramSearcher.threshold_literal(RecordingStudioSearch.configuration.trigram_threshold)
      end

      def assign_similarity_threshold(value)
        connection.execute(
          model.sanitize_sql_array(["SET LOCAL pg_trgm.similarity_threshold = ?", value.to_s])
        )
      end
    end
    private_constant :Thresholded
  end
end
