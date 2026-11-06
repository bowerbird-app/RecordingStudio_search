# frozen_string_literal: true

require "test_helper"

class DummyAccessTest < ActiveSupport::TestCase
  setup do
    @owner = User.find_or_create_by!(email: "dummy-access-owner@example.com") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
      account.name = "Owner"
    end
    @stranger = User.find_or_create_by!(email: "dummy-access-stranger@example.com") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
      account.name = "Stranger"
    end
  end

  test "record_under_workspace! does not self-grant when the actor cannot edit" do
    DummyAccess.bootstrap_workspace!(name: "Owner Only Workspace", actor: @owner)
    page = Page.create!(title: "Secret page", body: "not for strangers")

    assert_raises(RecordingStudio::AuthorizationError) do
      DummyAccess.record_under_workspace!(
        page,
        actor: @stranger,
        workspace_name: "Owner Only Workspace"
      )
    end
    assert_nil RecordingStudio::Recording.find_by(recordable: page)
  end

  test "bootstrap_workspace! raises when Accessible bootstrap fails" do
    DummyAccess.bootstrap_workspace!(name: "Taken Workspace", actor: @owner)

    error = assert_raises(RuntimeError) do
      DummyAccess.bootstrap_workspace!(name: "Taken Workspace", actor: @stranger)
    end
    assert_match(/already|Access already exists|bootstrap/i, error.message)
  end

  test "dummy access helpers do not ignore grant failures or self-grant per request" do
    source = File.read(Rails.root.join("app/models/dummy_access.rb"))

    refute_includes source, "grant_access"
    refute_includes source, "ensure_owner!"
    refute_includes source, "trusted_write?"
    refute_includes source, "TRUSTED_WRITE_KEY"
    assert_includes source, "raise(result.error"
    assert_includes source, "bootstrap_owner_access!"
  end
end
