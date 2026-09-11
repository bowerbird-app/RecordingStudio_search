class Page < ApplicationRecord
  include RecordingStudioSearch::Searchable

  recording_studio_recordable label: "Page", root: false, allowed_parent_types: [ "Workspace", "Folder" ]

  searchable backend: :pgvector, against: { title: "A", body: "D" }, recording_id: :search_recording_id

  def search_recording_id
    RecordingStudio::Recording.find_by(recordable_type: self.class.name, recordable_id: id)&.id
  end
end
