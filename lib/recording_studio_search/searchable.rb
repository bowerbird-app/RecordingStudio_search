# frozen_string_literal: true

module RecordingStudioSearch
  module Searchable
    extend ActiveSupport::Concern

    included do
      def recording_studio_search_embed_later
        RecordingStudioSearch.embed_later(self)
      end

      def recording_studio_search_text
        entry = RecordingStudioSearch::Registry.entry_for(self.class)
        return "" unless entry

        entry.against.map do |column|
          text = public_send(column).to_s
          repeats = Schema::EMBED_REPEATS[entry.weights[column]] || 1
          ([text] * repeats).join("\n")
        end.join("\n")
      end
    end

    class_methods do
      def searchable(against:, backend: nil, recording_id: nil)
        chosen = (backend || RecordingStudioSearch.configuration.default_backend).to_sym
        raise ArgumentError, "Unknown search backend #{chosen.inspect}" unless Configuration::BACKENDS.include?(chosen)

        columns = Schema.parse_against(against)
        raise ArgumentError, "searchable requires against: fields" if columns.empty?

        RecordingStudioSearch::Registry.register(
          self,
          backend: chosen,
          against: against,
          recording_id: recording_id
        )

        return if @recording_studio_search_callbacks_installed

        @recording_studio_search_callbacks_installed = true
        after_commit :recording_studio_search_embed_later, on: %i[create update],
                                                           if: :recording_studio_search_vector_backend?
      end

      def search(query, limit: nil)
        RecordingStudioSearch.search(all, query, limit: limit)
      end
    end

    def recording_studio_search_vector_backend?
      RecordingStudioSearch::Registry.entry_for(self.class)&.backend == :pgvector
    end
  end
end
