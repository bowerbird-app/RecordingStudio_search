# frozen_string_literal: true

module RecordingStudioSearch
  class EmbedDocumentJob < ActiveJob::Base
    queue_as :default

    def perform(searchable_type:, searchable_id:, recording_id: nil)
      DocumentEmbedder.call(
        searchable_type: searchable_type,
        searchable_id: searchable_id,
        recording_id: recording_id
      )
    end
  end
end
