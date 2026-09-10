# frozen_string_literal: true

module RecordingStudioSearch
  module Registry
    Entry = Struct.new(
      :model,
      :backend,
      :against,
      :recording_id_method,
      keyword_init: true
    )

    module_function

    def entries
      @entries ||= {}
    end

    def reset!
      @entries = {}
    end

    def register(model, backend:, against:, recording_id: nil)
      entries[model.name] = Entry.new(
        model: model,
        backend: backend.to_sym,
        against: Array(against).map(&:to_sym),
        recording_id_method: recording_id&.to_sym
      )
    end

    def entry_for(model)
      entries[model.name]
    end

    def pgvector_entries
      entries.values.select { |entry| entry.backend == :pgvector }
    end
  end
end
