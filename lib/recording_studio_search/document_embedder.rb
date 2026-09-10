# frozen_string_literal: true

module RecordingStudioSearch
  class DocumentEmbedder
    def self.call(searchable_type:, searchable_id:, recording_id: nil)
      new(
        searchable_type: searchable_type,
        searchable_id: searchable_id,
        recording_id: recording_id
      ).call
    end

    def initialize(searchable_type:, searchable_id:, recording_id: nil)
      @searchable_type = searchable_type
      @searchable_id = searchable_id
      @recording_id = recording_id.presence
      @adapter = EmbeddingAdapter.new
    end

    def call
      record = searchable_type.constantize.find_by(id: searchable_id)
      return unless record

      digest = Normalize.content_digest(record.recording_studio_search_text)
      document = find_document(record)
      return if document && document.content_digest == digest && document.embedding.present?

      unless adapter.available?
        Rails.logger.error(
          "[recording_studio_search] embed skipped; no embedding client " \
          "model=#{searchable_type} id=#{searchable_id}"
        )
        return
      end

      vector = adapter.embed(text: record.recording_studio_search_text)
      attrs = {
        searchable_type: searchable_type,
        searchable_id: record.id,
        recording_id: recording_id_for(record),
        embedding: vector,
        embedding_at: Time.current,
        embedding_model: RecordingStudioSearch.configuration.embedding_model,
        content_digest: digest
      }

      if document
        document.update!(attrs)
      else
        Document.create!(attrs)
      end
    rescue EmbeddingAdapter::Error, StandardError => e
      Rails.logger.error(
        "[recording_studio_search] embed failed model=#{searchable_type} " \
        "id=#{searchable_id} error=#{e.class}: #{e.message}"
      )
    end

    private

    attr_reader :searchable_type, :searchable_id, :recording_id, :adapter

    def find_document(record)
      stable_id = recording_id_for(record)
      if stable_id
        Document.find_by(recording_id: stable_id) ||
          Document.find_by(searchable_type: searchable_type, searchable_id: record.id)
      else
        Document.find_by(searchable_type: searchable_type, searchable_id: record.id)
      end
    end

    def recording_id_for(record)
      recording_id.presence || RecordingStudioSearch.recording_id_for(record)
    end
  end
end
