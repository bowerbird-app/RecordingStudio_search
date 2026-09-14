# frozen_string_literal: true

module RecordingStudioSearch
  module ResultsHelper
    def instant_search_result_collections(hits)
      return [] if hits.blank?
      return hash_collections(hits) if hits.is_a?(Hash)

      [["", hits]]
    end

    def hash_collections(hits)
      hits.filter_map do |model, relation|
        next if relation.blank?

        [instant_search_collection_label(model), relation]
      end
    end

    def instant_search_collection_label(model)
      name = model.respond_to?(:name) ? model.name : model.to_s
      name.demodulize.pluralize
    end

    def instant_search_row_name(row)
      row.try(:name).presence || row.try(:title).presence || row.to_s
    end

    def instant_search_row_detail(row)
      row.try(:email).presence || row.try(:body).to_s.truncate(80).presence || "—"
    end
  end
end
