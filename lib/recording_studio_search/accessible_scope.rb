# frozen_string_literal: true

module RecordingStudioSearch
  # Instant search and dummy lookups ask Accessible which recordings the actor
  # may view. Missing Accessible or a blank actor is empty, not everyone.
  # Scope is bulk-loaded from Accessible before ranking or limit.
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

      ids = descendant_recording_ids(actor)
      return [] if ids.empty?

      RecordingStudio::Recording.where(id: ids).includes(:recordable).reorder(:created_at, :id).to_a
    end

    def recordable_ids(model, actor)
      return [] unless accessible?
      return [] if actor.blank?
      return [] unless defined?(RecordingStudio::Recording)

      recordings_for(actor).filter_map do |recording|
        recording.recordable_id if recording.recordable_type == model.name
      end
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

    def descendant_recording_ids(actor)
      seen = {}
      queue = Array(
        RecordingStudioAccessible.root_recordings_for(actor: actor, minimum_role: VIEW_ROLE)
      )

      until queue.empty?
        recording = queue.shift
        next if recording.blank? || seen[recording.id]

        seen[recording.id] = true
        children = RecordingStudioAccessible.recordings_for(
          actor: actor,
          parent_recording: recording,
          minimum_role: VIEW_ROLE
        )
        Array(children).each { |child| queue << child }
      end

      seen.keys
    end
    private_class_method :descendant_recording_ids
  end
end
