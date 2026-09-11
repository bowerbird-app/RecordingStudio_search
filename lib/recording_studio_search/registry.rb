# frozen_string_literal: true

module RecordingStudioSearch
  module Registry
    Entry = Struct.new(
      :model,
      :backend,
      :against,
      :weights,
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
      parsed = Schema.fields(against)
      entries[model.name] = Entry.new(
        model: model,
        backend: backend.to_sym,
        against: parsed.map { |field| field.column.to_sym },
        weights: parsed.to_h { |field| [field.column.to_sym, field.weight] }.compact,
        recording_id_method: recording_id&.to_sym
      )
    end

    def entry_for(model)
      entries[model_class(model).name]
    end

    def model_class(model)
      model.is_a?(ActiveRecord::Relation) ? model.klass : model
    end

    def pgvector_entries
      entries.values.select { |entry| entry.backend == :pgvector }
    end
  end
end
