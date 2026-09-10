# frozen_string_literal: true

module RecordingStudioSearch
  class Document < ApplicationRecord
    self.table_name = "recording_studio_search_documents"

    def embedding=(value)
      super(value.is_a?(Array) ? Normalize.vector_literal(value) : value)
    end
  end
end
