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

  test "same actor with view on two roots does not see the other root's page" do
    root_a = DummyAccess.bootstrap_workspace!(name: "Search Query Root A", actor: @owner)
    root_b = DummyAccess.bootstrap_workspace!(name: "Search Query Root B", actor: @owner)
    hidden = Page.find_or_create_by!(title: "Cross Root Zebra") do |record|
      record.body = "A zebra page that lives only under root B."
    end
    DummyAccess.record_under_workspace!(
      hidden,
      actor: @owner,
      workspace_name: "Search Query Root B"
    )

    payload = RecordingStudioSearch::Api::Query.call(
      Context.new(
        access_grant: AccessGrant.new(@owner),
        root_recording: root_a,
        params: { q: "zebra", models: ["Page"] }
      )
    )
    ids = payload.fetch(:hits).map { |row| row[:id] }

    refute_includes ids, hidden.id
    assert RecordingStudioAccessible.authorized?(actor: @owner, recording: root_a, role: :view)
    assert RecordingStudioAccessible.authorized?(actor: @owner, recording: root_b, role: :view)
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

class SearchQueryApiHttpTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.find_or_create_by!(email: "search-query-http-owner@example.com") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
      account.name = "Owner"
    end
    @root = DummyAccess.bootstrap_workspace!(name: "Search Query HTTP Workspace", actor: @owner)
    @page = Page.find_or_create_by!(title: "Search Query HTTP Refunds") do |record|
      record.body = "How to request a refund when a charge looks wrong."
    end
    DummyAccess.record_under_workspace!(
      @page,
      actor: @owner,
      workspace_name: "Search Query HTTP Workspace"
    )
  end

  test "search.query returns 200 for a token with view on the root" do
    get "/recording_studio_api/api/v1/search/query",
        params: { q: "refund", models: ["Page"] },
        headers: bearer_headers(issue_token_for(@owner, @root).fetch(:token))

    assert_response :success
    ids = JSON.parse(response.body).fetch("hits").map { |row| row.fetch("id") }
    assert_includes ids, @page.id
  end

  test "search.query returns 401 without a token" do
    get "/recording_studio_api/api/v1/search/query", params: { q: "refund", models: ["Page"] }

    assert_response :unauthorized
  end

  test "search.query returns 403 when the actor cannot view the root" do
    issued = issue_token_for(@owner, @root)
    RecordingStudio::Access.where(id: issued.fetch(:access_recording).recordable_id).update_all(role: "")
    refute RecordingStudioAccessible.authorized?(
      actor: issued.fetch(:access_recording).recordable.reload.actor,
      recording: @root,
      role: :view
    )

    get "/recording_studio_api/api/v1/search/query",
        params: { q: "refund", models: ["Page"] },
        headers: bearer_headers(issued.fetch(:token))

    assert_response :forbidden
  end

  private

  def bearer_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end

  def access_recording_for(actor, root)
    RecordingStudioAccessible.access_recordings_for_actor(recording: root, actor: actor).first
  end

  def issue_token_for(actor, root)
    access_recording = access_recording_for(actor, root)
    raise "missing access recording" if access_recording.blank?

    provision = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: root,
      manager_actor: actor,
      role: access_recording.recordable.role,
      name: "Search query HTTP client #{SecureRandom.hex(4)}"
    )
    raise provision.error unless provision.success?

    token_result = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: provision.value.fetch(:credential).oauth_client_id,
      client_secret: provision.value.fetch(:token)
    )
    raise token_result.error unless token_result.success?

    {
      token: token_result.value.fetch(:access_token),
      access_recording: provision.value.fetch(:access_recording)
    }
  end
end
