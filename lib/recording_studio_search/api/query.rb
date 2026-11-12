# frozen_string_literal: true

module RecordingStudioSearch
  module Api
    class Query
      def self.call(context)
        grant = context.access_grant
        grant.authorize!(recording: context.root_recording, role: VIEW_ROLE)

        hits = InstantSearch.hits_for(
          requested_models(context.params),
          query(context.params),
          actor: grant.actor,
          limit: limit(context.params)
        )
        { hits: rows_for(hits) }
      end

      def self.requested_models(params)
        raw = params[:models]
        raw = raw.values if raw.respond_to?(:values)
        requested = Array(raw).filter_map(&:presence)
        return requested if requested.any?

        InstantSearch.allowlisted_by_name.keys
      end

      def self.query(params)
        params[:q].to_s
      end

      def self.limit(params)
        Integer(params[:limit], exception: false) || DEFAULT_LIMIT
      end

      def self.rows_for(hits)
        return [] if hits.blank?

        if hits.is_a?(Hash)
          hits.flat_map { |model, relation| rows_for_relation(relation, model) }
        else
          rows_for_relation(hits, hits.klass)
        end
      end

      def self.rows_for_relation(relation, model)
        Array(relation).map { |record| row_for(record, model) }
      end

      def self.row_for(record, model)
        {
          type: model.name,
          id: record.id,
          recording_id: RecordingStudioSearch.recording_id_for(record)
        }
      end

      private_class_method :requested_models, :query, :limit, :rows_for, :rows_for_relation, :row_for
    end
  end
end
