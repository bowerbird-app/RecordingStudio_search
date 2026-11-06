# frozen_string_literal: true

# Dummy-only Accessible grants and tree placement. Not part of the gem API.
module DummyAccess
  module_function

  def as_actor(actor)
    previous = Current.actor
    Current.actor = actor
    yield
  ensure
    Current.actor = previous
  end

  def authorize_write?(actor:, recording: nil, parent_recording: nil, root_recording: nil, recordable: nil, **)
    return false if actor.blank?

    # Accessible grant/bootstrap writes Access rows inside AccessCreationContext.
    return true if RecordingStudioAccessible::AccessCreationContext.allowed?
    # Users records a Profile under shared People before bootstrap_owner_access!.
    return true if recordable.is_a?(RecordingStudioUser::Profile) && recording.blank?

    target = recording || parent_recording || root_recording
    return false if target.blank?

    RecordingStudioAccessible.authorized?(actor: actor, recording: target, role: :edit)
  end

  def bootstrap_workspace!(name:, actor:)
    raise ArgumentError, "actor is required" if actor.blank?
    raise ArgumentError, "name is required" if name.blank?

    as_actor(actor) do
      workspace = Workspace.find_or_create_by!(name: name)
      root = RecordingStudio.root_recording_for(workspace)
      result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: actor)
      raise(result.error.presence || "Accessible bootstrap failed") if result.failure?

      root
    end
  end

  def record_under_workspace!(recordable, actor:, workspace_name: "Studio Workspace")
    raise ArgumentError, "actor is required" if actor.blank?
    raise ArgumentError, "recordable is required" if recordable.blank?

    workspace = Workspace.find_by!(name: workspace_name)
    previous = Current.actor
    Current.actor = actor
    root = RecordingStudio::Recording.find_by!(recordable: workspace)
    unless RecordingStudioAccessible.authorized?(actor: actor, recording: root, role: :edit)
      raise RecordingStudio::AuthorizationError,
            "RecordingStudio write was denied by config.authorize_write"
    end

    RecordingStudio::Recording.find_by(recordable: recordable) ||
      RecordingStudio.record!(
        action: "created",
        recordable: recordable,
        root_recording: root,
        parent_recording: root
      ).recording
  ensure
    Current.actor = previous
  end
end
