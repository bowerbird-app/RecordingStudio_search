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

    # Public data: raw English collection label from the model class name.
    # Translate at the render site via +instant_search_translated_collection_label+.
    def instant_search_collection_label(model)
      name = model.respond_to?(:name) ? model.name : model.to_s
      name.demodulize.pluralize
    end

    # Render-time translation of a collection section title. +label+ stays the
    # raw English from +instant_search_collection_label+ (or ""). Optional host
    # keys under results.collections.* are not shipped in this gem's en.yml, so
    # they stay on view +t+ / +I18n.t+ with main's +default: label+ (not
    # +RecordingStudio.t+, which is only for this gem's shipped keys).
    def instant_search_translated_collection_label(label)
      return label if label.blank?

      key = label.to_s.underscore
      t("recording_studio.search.results.collections.#{key}", default: label)
    end

    def instant_search_row_name(row)
      row.try(:name).presence || row.try(:title).presence || row.to_s
    end

    def instant_search_row_detail(row)
      row.try(:email).presence ||
        row.try(:body).to_s.truncate(80).presence ||
        RecordingStudio.t("recording_studio.search.results.missing_detail")
    end
  end
end
