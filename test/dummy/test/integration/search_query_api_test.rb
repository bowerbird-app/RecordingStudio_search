# frozen_string_literal: true

require "test_helper"

class SearchQueryApiTest < ActiveSupport::TestCase
  class AccessGrant
    def initialize(actor)
      @actor = actor
    end

    attr_reader :actor

    def authorize!(recording:, role:, **)
      allowed = recording.present? &&
                RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: role)
      return if allowed

      raise "API access grant is not authorized for this capability"
    end
  end

  Context = Struct.new(:access_grant, :root_recording, :params, keyword_init: true)

  setup do
    @owner = User.find_or_create_by!(email: "search-query-owner@example.com") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
      account.name = "Owner"
    end
    @stranger = User.find_or_create_by!(email: "search-query-stranger@example.com") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
      account.name = "Stranger"
    end
    @owner_root = DummyAccess.bootstrap_workspace!(name: "Search Query Owner Workspace", actor: @owner)
    @stranger_root = DummyAccess.bootstrap_workspace!(name: "Search Query Stranger Workspace", actor: @stranger)
    @page = Page.find_or_create_by!(title: "Search Query Refunds") do |record|
      record.body = "How to request a refund when a charge looks wrong."
    end
    DummyAccess.record_under_workspace!(
      @page,
      actor: @owner,
      workspace_name: "Search Query Owner Workspace"
    )
  end

  test "authorized caller receives ranked hits for a page they can view" do
    payload = RecordingStudioSearch::Api::Query.call(owner_context(q: "refund"))

    hit = payload.fetch(:hits).find { |row| row[:id] == @page.id }
    assert hit, "owner should see the refunds page"
    assert_equal "Page", hit.fetch(:type)
    assert_equal @page.search_recording_id, hit.fetch(:recording_id)
  end

  test "caller without access to the root is denied" do
    error = assert_raises(RuntimeError) do
      RecordingStudioSearch::Api::Query.call(
        Context.new(
          access_grant: AccessGrant.new(@stranger),
          root_recording: @owner_root,
          params: { q: "refund", models: ["Page"] }
        )
      )
    end

    assert_match(/not authorized/, error.message)
  end

  test "authorized caller does not see a page granted only to someone else" do
    owner_payload = RecordingStudioSearch::Api::Query.call(owner_context(q: "refund"))
    stranger_payload = RecordingStudioSearch::Api::Query.call(
      Context.new(
        access_grant: AccessGrant.new(@stranger),
        root_recording: @stranger_root,
        params: { q: "refund", models: ["Page"] }
      )
    )

    owner_ids = owner_payload.fetch(:hits).map { |row| row[:id] }
    stranger_ids = stranger_payload.fetch(:hits).map { |row| row[:id] }

    assert_includes owner_ids, @page.id
    refute_includes stranger_ids, @page.id
  end

  test "dummy workspace no longer includes the example mixin" do
    workspace_source = File.read(Rails.root.join("app/models/workspace.rb"))

    refute_includes workspace_source, "Capabilities::Example"
    refute RecordingStudio.registered_capabilities.key?(:example)
    refute RecordingStudio.capability_enabled?(:example, for: Workspace)
    assert RecordingStudio.capability_enabled?(:accessible, for: Workspace)
  end

  private

  def owner_context(q:)
    Context.new(
      access_grant: AccessGrant.new(@owner),
      root_recording: @owner_root,
      params: { q: q, models: ["Page"] }
    )
  end
end
