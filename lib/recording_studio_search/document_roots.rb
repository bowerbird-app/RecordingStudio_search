# frozen_string_literal: true

module RecordingStudioSearch
  module DocumentRoots
    module_function

    def backfill!(connection = Document.connection)
      connection.execute(<<~SQL.squish)
        UPDATE recording_studio_search_documents AS documents
        SET root_recording_id = COALESCE(recordings.root_recording_id, recordings.id)
        FROM recording_studio_recordings AS recordings
        WHERE documents.recording_id = recordings.id
          AND documents.root_recording_id IS NULL
      SQL
    end
  end
end
