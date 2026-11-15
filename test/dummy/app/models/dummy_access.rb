# frozen_string_literal: true

# Dummy-only Accessible grants and tree placement. Not part of the gem API.
module DummyAccess
  ROOT_CREATION = :recording_studio_search_dummy_root_creation

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

    # Grant/bootstrap may write Access rows only. Other recordables stay closed.
    if RecordingStudioAccessible::AccessCreationContext.allowed?
      return recordable.is_a?(RecordingStudio::Access)
    end

    # Core 7 creates a root with recording, parent, and root all nil.
    # That write stays closed unless record_root! opened it for seeds or bootstrap.
    if recording.nil? && parent_recording.nil? && root_recording.nil?
      return false unless creating_root?
      return false unless actor.is_a?(User) && actor.persisted?
      return false if recordable.nil?

      return RecordingStudio.root_allowed?(recordable)
    end

    target = recording || parent_recording || root_recording
    return false if target.blank?

    required_role = recordable.is_a?(RecordingStudio::Access) ? :admin : :edit
    RecordingStudioAccessible.authorized?(actor: actor, recording: target, role: required_role)
  end

  def creating_root
    previous = Thread.current[ROOT_CREATION]
    Thread.current[ROOT_CREATION] = true
    yield
  ensure
    Thread.current[ROOT_CREATION] = previous
  end

  def creating_root?
    Thread.current[ROOT_CREATION] == true
  end

  # Seeds and bootstrap create roots here. A direct create_root_recording! stays denied.
  def record_root!(recordable, actor:)
    raise ArgumentError, "actor is required" if actor.blank?
    raise ArgumentError, "recordable is required" if recordable.blank?

    as_actor(actor) do
      creating_root { RecordingStudio.create_root_recording!(recordable, actor: actor) }
    end
  end

  def bootstrap_workspace!(name:, actor:)
    raise ArgumentError, "actor is required" if actor.blank?
    raise ArgumentError, "name is required" if name.blank?

    as_actor(actor) do
      workspace = Workspace.find_or_create_by!(name: name)
      root = record_root!(workspace, actor: actor)
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

  private_class_method :creating_root, :creating_root?
end
