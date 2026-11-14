# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

find_or_record_child = lambda do |recordable, root_recording, parent_recording|
  RecordingStudio::Recording.where(
    RecordingStudio::Recording.recording_studio_trashable_kept_sql
  ).find_by(
    root_recording: root_recording,
    parent_recording: parent_recording,
    recordable: recordable
  ) || RecordingStudio.record!(
    action: "created",
    recordable: recordable,
    root_recording: root_recording,
    parent_recording: parent_recording
  ).recording
end

bootstrap_owner_access = lambda do |actor, recording|
  result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
  raise result.error if result.failure?
end

user = User.find_or_create_by!(email: "admin@admin.com") do |account|
  account.password = "Password123!"
  account.password_confirmation = "Password123!"
  account.name = "Ada Admin"
end
user.update!(name: "Ada Admin") if user.name.blank?

previous_actor = Current.actor
Current.actor = user

begin
  lovelace = User.find_or_create_by!(email: "ada@example.com") do |account|
    account.password = "Password123!"
    account.password_confirmation = "Password123!"
    account.name = "Ada Lovelace"
  end
  lovelace.update!(name: "Ada Lovelace") if lovelace.name.blank?

  hopper = User.find_or_create_by!(email: "grace@hopper.test") do |account|
    account.password = "Password123!"
    account.password_confirmation = "Password123!"
    account.name = "Grace Hopper"
  end
  hopper.update!(name: "Grace Hopper") if hopper.name.blank?

  workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
  accessible_workspace = Workspace.find_or_create_by!(name: "Client Workspace")
  private_workspace = Workspace.find_or_create_by!(name: "Private Workspace")
  folder = Folder.find_or_create_by!(name: "Product Docs")
  page = Page.find_or_initialize_by(title: "Getting Started")
  if page.new_record?
    page.body = "Welcome to the studio. Set a password you can remember."
    page.save!
  end

  refund_page = Page.find_or_initialize_by(title: "Refunds")
  if refund_page.new_record?
    refund_page.body = "How to request a refund when a charge looks wrong."
    refund_page.save!
  end

  widgets_page = Page.find_or_initialize_by(title: "Widgets")
  if widgets_page.new_record?
    widgets_page.body = "unrelated copy"
    widgets_page.save!
  end

  body_widgets_page = Page.find_or_initialize_by(title: "Something else")
  if body_widgets_page.new_record?
    body_widgets_page.body = "Widgets appear in the body only"
    body_widgets_page.save!
  end

  Note.find_or_create_by!(title: "Sticky reminder")

  root_recording = RecordingStudio.root_recording_for(workspace)
  accessible_root_recording = RecordingStudio.root_recording_for(accessible_workspace)
  private_root_recording = RecordingStudio.root_recording_for(private_workspace)
  bootstrap_owner_access.call(user, root_recording)

  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)
  find_or_record_child.call(page, root_recording, folder_recording)
  find_or_record_child.call(refund_page, root_recording, folder_recording)
  DummyAccess.record_under_workspace!(widgets_page, actor: user)
  DummyAccess.record_under_workspace!(body_widgets_page, actor: user)
ensure
  Current.actor = previous_actor
end

[page, refund_page].each do |record|
  RecordingStudioSearch::DocumentEmbedder.call(
    searchable_type: record.class.name,
    searchable_id: record.id,
    recording_id: record.search_recording_id
  )
end

puts "Seeded: admin@admin.com / Password123!"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Workspace '#{accessible_workspace.name}' with root recording ##{accessible_root_recording.id}"
puts "Seeded: Workspace '#{private_workspace.name}' with root recording ##{private_root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and pages '#{page.title}', '#{refund_page.title}'"
