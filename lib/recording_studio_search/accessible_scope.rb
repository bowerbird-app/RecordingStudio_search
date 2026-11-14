# frozen_string_literal: true

module RecordingStudioSearch
  # Viewable recordings for one actor under one root.
  #
  # Accessible's +authorized_recording_ids+ is an unloaded id relation (a
  # recursive CTE). Search keeps that relation in SQL and applies LIMIT on
  # the same statement. Trashed recordings stay in the Accessible set, so
  # this scope drops +trashed_at+. A blank actor, a blank root, a missing
  # Accessible, or an authorization service that cannot answer the id query
  # is empty. It is never every row.
  module AccessibleScope
    VIEW_ROLE = :view

    module_function

    def relation_for(model, actor, root: nil)
      return none_for(model) unless searchable_model?(model)
      return none_for(model) unless scope_ready?(actor, root)

      model.where(id: recordable_id_relation(model, actor, root))
    end

    def recordable_ids(model, actor, root: nil)
      return [] unless scope_ready?(actor, root)

      recordable_id_relation(model, actor, root)
    end

    # Unloaded relation of recording ids the actor can view. Trashed rows
    # are already removed. +recordable_type+ drops access recordings.
    def recording_ids_for(actor, root:, recordable_type: nil)
      return recording_none unless scope_ready?(actor, root)

      visible_recordings(actor, root: root, recordable_type: recordable_type).select(:id)
    end

    def recordings_for(actor, root: nil)
      return [] unless scope_ready?(actor, root)

      visible_recordings(actor, root: root).includes(:recordable).reorder(:created_at, :id).to_a
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

    def scope_ready?(actor, root)
      accessible? && actor.present? && root.present? && authorized_ids_supported?
    end

    def authorized_ids_supported?
      return false unless accessible?
      return false unless RecordingStudioAccessible.respond_to?(:authorized_recording_ids_supported?)

      RecordingStudioAccessible.authorized_recording_ids_supported?
    rescue RecordingStudioAccessible::Error
      false
    end

    def visible_recordings(actor, root:, recordable_type: nil)
      scope = RecordingStudio::Recording.where(
        id: authorized_ids(actor, root, recordable_type: recordable_type)
      )
      exclude_trashed(scope)
    end

    def authorized_ids(actor, root, recordable_type:)
      return recording_none unless authorized_ids_supported?

      RecordingStudioAccessible.authorized_recording_ids(
        actor: actor,
        root: root,
        role: VIEW_ROLE,
        recordable_type: recordable_type
      )
    rescue RecordingStudioAccessible::Error
      recording_none
    end

    def recordable_id_relation(model, actor, root)
      visible_recordings(
        actor,
        root: root,
        recordable_type: model_name(model)
      ).select(:recordable_id)
    end

    def model_name(model)
      model.respond_to?(:klass) ? model.klass.name : model.name
    end

    def exclude_trashed(scope)
      return scope unless recording_class
      return scope unless recording_class.column_names.include?("trashed_at")

      scope.where(trashed_at: nil)
    end

    def recording_none
      recording_class ? recording_class.none : []
    end

    def recording_class
      return unless defined?(RecordingStudio::Recording)

      RecordingStudio::Recording
    end

    private_class_method :scope_ready?, :authorized_ids_supported?, :visible_recordings,
                         :authorized_ids, :recordable_id_relation, :model_name,
                         :exclude_trashed, :recording_none, :recording_class
  end
end
