# frozen_string_literal: true

class AddRootRecordingIdToRecordingStudioSearchDocuments < ActiveRecord::Migration[8.1]
  INDEX_NAME = "index_rss_documents_on_root_and_type"

  def up
    report_vector_version

    unless column_exists?(:recording_studio_search_documents, :root_recording_id)
      add_column :recording_studio_search_documents, :root_recording_id, :uuid
    end

    RecordingStudioSearch::DocumentRoots.backfill!(connection)

    return if index_exists?(:recording_studio_search_documents, %i[root_recording_id searchable_type], name: INDEX_NAME)

    add_index :recording_studio_search_documents,
              %i[root_recording_id searchable_type],
              name: INDEX_NAME
  end

  def down
    if index_exists?(:recording_studio_search_documents, %i[root_recording_id searchable_type], name: INDEX_NAME)
      remove_index :recording_studio_search_documents, name: INDEX_NAME
    end

    return unless column_exists?(:recording_studio_search_documents, :root_recording_id)

    remove_column :recording_studio_search_documents, :root_recording_id
  end

  private

  def report_vector_version
    version = RecordingStudioSearch::VectorScan.extension_version(connection)
    return if version.present? && version >= RecordingStudioSearch::VectorScan::ITERATIVE_VERSION

    warn(
      "[recording_studio_search] pgvector #{version || "missing"} is below 0.8; " \
      "filtered vector search uses an exact scan. The HNSW cosine index stays."
    )
  end
end
