# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

find_or_record_child = lambda do |recordable, root_recording, parent_recording|
  RecordingStudio::Recording.find_by(
    root_recording: root_recording,
    parent_recording: parent_recording,
    recordable: recordable,
    trashed_at: nil
  ) || RecordingStudio.record!(
    action: "created",
    recordable: recordable,
    root_recording: root_recording,
    parent_recording: parent_recording
  ).recording
end

user = User.find_or_create_by!(email: "admin@admin.com") do |account|
  account.password = "Password"
  account.password_confirmation = "Password"
  account.name = "Ada Admin"
end
user.update!(name: "Ada Admin") if user.name.blank?

RecordingStudioUser.record_profile!(user, first_name: "Ada", last_name: "Admin", time_zone: "UTC") unless RecordingStudioUser.profile_for(user)

lovelace = User.find_or_create_by!(email: "ada@example.com") do |account|
  account.password = "Password"
  account.password_confirmation = "Password"
  account.name = "Ada Lovelace"
end
lovelace.update!(name: "Ada Lovelace") if lovelace.name.blank?

RecordingStudioUser.record_profile!(lovelace, first_name: "Ada", last_name: "Lovelace", time_zone: "UTC") unless RecordingStudioUser.profile_for(lovelace)

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

Note.find_or_create_by!(title: "Sticky reminder")

previous_actor = Current.actor
Current.actor = user

begin
  root_recording = RecordingStudio.root_recording_for(workspace)
  accessible_root_recording = RecordingStudio.root_recording_for(accessible_workspace)
  private_root_recording = RecordingStudio.root_recording_for(private_workspace)

  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)
  find_or_record_child.call(page, root_recording, folder_recording)
  find_or_record_child.call(refund_page, root_recording, folder_recording)
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

puts "Seeded: admin@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Workspace '#{accessible_workspace.name}' with root recording ##{accessible_root_recording.id}"
puts "Seeded: Workspace '#{private_workspace.name}' with root recording ##{private_root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and pages '#{page.title}', '#{refund_page.title}'"
