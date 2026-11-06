# frozen_string_literal: true

module RecordingStudioSearch
  # Instant search and dummy lookups ask Accessible which recordings the actor
  # may view. Missing Accessible or a blank actor is empty, not everyone.
  module AccessibleScope
    VIEW_ROLE = :view

    module_function

    def relation_for(model, actor)
      return none_for(model) unless searchable_model?(model)

      ids = recordable_ids(model, actor)
      return none_for(model) if ids.empty?

      model.where(id: ids)
    end

    def recordings_for(actor)
      return [] unless accessible?
      return [] if actor.blank?

      RecordingStudio::Recording.includes(:recordable).reorder(:created_at, :id).select do |recording|
        authorized?(actor, recording)
      end
    end

    def recordable_ids(model, actor)
      return [] unless accessible?
      return [] if actor.blank?
      return [] unless defined?(RecordingStudio::Recording)

      RecordingStudio::Recording.where(recordable_type: model.name).filter_map do |recording|
        recording.recordable_id if authorized?(actor, recording)
      end
    end

    def authorized?(actor, recording)
      RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: VIEW_ROLE)
    end

    def accessible?
      defined?(RecordingStudioAccessible)
    end

    def searchable_model?(model)
      model.respond_to?(:where) && model.respond_to?(:none)
    end

    def none_for(model)
      searchable_model?(model) ? model.none : []
    end
  end
end
