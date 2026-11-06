# frozen_string_literal: true

# Dummy-only Accessible grants and tree placement. Not part of the gem API.
module DummyAccess
  module_function

  def ensure_owner!(actor:, recording:)
    return if actor.blank? || recording.blank?
    return if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)

    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
    return if result.success?

    RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: :admin,
      manager_actor: actor
    )
  end

  def record_under_workspace!(recordable, actor:, workspace_name: "Studio Workspace")
    return if actor.blank? || recordable.blank?

    workspace = Workspace.find_or_create_by!(name: workspace_name)
    previous = Current.actor
    Current.actor = actor
    root = RecordingStudio.root_recording_for(workspace)
    ensure_owner!(actor: actor, recording: root)
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
