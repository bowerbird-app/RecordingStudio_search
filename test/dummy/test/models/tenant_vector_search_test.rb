# frozen_string_literal: true

require "test_helper"

class TenantVectorSearchTest < ActiveSupport::TestCase
  QUERY = "tenant-vector-query"
  LIMIT = 5
  CLOSER_COUNT = 8

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
    RecordingStudioSearch::Document.delete_all
    RecordingStudioSearch::Query.delete_all
  end

  test "documents table keeps the tenant root, type, and cosine index" do
    connection = Page.connection

    assert connection.column_exists?(:recording_studio_search_documents, :root_recording_id)
    assert connection.column_exists?(:recording_studio_search_documents, :searchable_type)
    assert connection.index_exists?(
      :recording_studio_search_documents,
      %i[root_recording_id searchable_type],
      name: "index_rss_documents_on_root_and_type"
    )
    assert connection.index_exists?(
      :recording_studio_search_documents,
      :embedding,
      name: "index_rss_documents_on_embedding"
    )
  end

  test "backfill copies the recording root and does not replace one already set" do
    actor = user_named("backfill")
    workspace_name = unique_name("Backfill")
    root = DummyAccess.bootstrap_workspace!(name: workspace_name, actor: actor)
    page = Page.create!(title: unique_name("Backfill page"), body: "notes")
    recording = DummyAccess.record_under_workspace!(page, actor: actor, workspace_name: workspace_name)
    document = RecordingStudioSearch::Document.create!(
      searchable_type: "Page",
      searchable_id: page.id,
      recording_id: recording.id,
      embedding: query_vector,
      embedding_at: Time.current,
      embedding_model: RecordingStudioSearch.configuration.embedding_model,
      content_digest: "backfill-#{page.id}"
    )
    document.update_column(:root_recording_id, nil)

    RecordingStudioSearch::DocumentRoots.backfill!

    assert_equal root.id, document.reload.root_recording_id

    other_root = SecureRandom.uuid
    document.update_column(:root_recording_id, other_root)
    RecordingStudioSearch::DocumentRoots.backfill!

    assert_equal other_root, document.reload.root_recording_id
  end

  test "requesting tenant keeps its own top matches when another tenant is closer" do
    world = two_tenants

    logs = capture_logs do
      @payload = RecordingStudioSearch::Api::Query.call(
        Context.new(
          access_grant: AccessGrant.new(world.fetch(:owner)),
          root_recording: world.fetch(:root),
          params: { q: QUERY, models: ["Page"], limit: LIMIT }
        )
      )
    end

    ids = @payload.fetch(:hits).map { |row| row.fetch(:id) }

    refute_match(/falling back/, logs)
    assert_equal [world.fetch(:near).id, world.fetch(:far).id], ids
    world.fetch(:closer_ids).each { |closer_id| refute_includes ids, closer_id }
  end

  test "instant search does not leak another tenant when that tenant is closer" do
    owner = user_named("instant-owner")
    stranger = user_named("instant-stranger")
    owned = tenant_pages(actor: owner, label: "Owned")
    hidden = tenant_pages(actor: stranger, label: "Hidden", shifts: { closer: 0.0 })

    logs = capture_logs do
      @hits = RecordingStudioSearch::InstantSearch.hits_for(
        ["Page"], QUERY, actor: owner, root: owned.fetch(:root), limit: LIMIT
      )
    end
    ids = Array(@hits).map(&:id)

    refute_match(/falling back/, logs)
    assert_equal [owned.fetch(:near).id, owned.fetch(:far).id], ids
    hidden.fetch(:closer_ids).each { |closer_id| refute_includes ids, closer_id }
  end

  test "exact filtered scan still keeps the requesting tenant" do
    world = two_tenants

    logs = capture_logs do
      RecordingStudioSearch::VectorScan.stub(:iterative?, false) do
        @payload = RecordingStudioSearch::Api::Query.call(
          Context.new(
            access_grant: AccessGrant.new(world.fetch(:owner)),
            root_recording: world.fetch(:root),
            params: { q: QUERY, models: ["Page"], limit: LIMIT }
          )
        )
      end
    end

    ids = @payload.fetch(:hits).map { |row| row.fetch(:id) }

    refute_match(/falling back/, logs)
    assert_equal [world.fetch(:near).id, world.fetch(:far).id], ids
    world.fetch(:closer_ids).each { |closer_id| refute_includes ids, closer_id }
  end

  test "a closer page in the same root is dropped when the actor cannot view it" do
    actor = user_named("same-root")
    workspace_name = unique_name("Same root")
    root = DummyAccess.bootstrap_workspace!(name: workspace_name, actor: actor)
    visible = Page.create!(title: unique_name("Visible ledger"), body: "notes")
    hidden = Page.create!(title: unique_name("Hidden ledger"), body: "notes")
    visible_recording = DummyAccess.record_under_workspace!(visible, actor: actor, workspace_name: workspace_name)
    hidden_recording = DummyAccess.record_under_workspace!(hidden, actor: actor, workspace_name: workspace_name)
    store_document(visible, visible_recording, 0.5)
    store_document(hidden, hidden_recording, 0.0)

    hits = RecordingStudioSearch.search(
      Page.where(id: visible.id),
      QUERY,
      limit: LIMIT,
      root_recording_id: root.id,
      unscoped: true
    )

    assert_equal [visible.id], hits.map(&:id)
    refute_includes hits.map(&:id), hidden.id
  end

  private

  def two_tenants
    owner = user_named("both-roots")
    home = tenant_pages(actor: owner, label: "Home")
    other = tenant_pages(actor: owner, label: "Other", shifts: { closer: 0.0 })
    home.merge(owner: owner, closer_ids: other.fetch(:closer_ids))
  end

  def tenant_pages(actor:, label:, shifts: { near: 0.5, far: 1.0 })
    workspace_name = unique_name(label)
    root = DummyAccess.bootstrap_workspace!(name: workspace_name, actor: actor)
    pages = {}
    closer_ids = []

    if shifts[:closer]
      CLOSER_COUNT.times do |index|
        page = Page.create!(title: unique_name("#{label} closer #{index}"), body: "notes")
        recording = DummyAccess.record_under_workspace!(page, actor: actor, workspace_name: workspace_name)
        store_document(page, recording, shifts[:closer])
        closer_ids << page.id
      end
    end

    %i[near far].each do |slot|
      next unless shifts[slot]

      page = Page.create!(title: unique_name("#{label} #{slot}"), body: "notes")
      recording = DummyAccess.record_under_workspace!(page, actor: actor, workspace_name: workspace_name)
      store_document(page, recording, shifts[slot])
      pages[slot] = page
    end

    { root: root, closer_ids: closer_ids }.merge(pages)
  end

  def store_document(page, recording, shift)
    RecordingStudioSearch::Document.find_or_initialize_by(
      searchable_type: "Page",
      searchable_id: page.id
    ).update!(
      recording_id: recording.id,
      root_recording_id: recording.root_recording_id,
      embedding: shifted_vector(shift),
      embedding_at: Time.current,
      embedding_model: RecordingStudioSearch.configuration.embedding_model,
      content_digest: "tenant-#{page.id}-#{shift}"
    )
  end

  def shifted_vector(shift)
    query_vector.each_with_index.map { |value, index| index.zero? ? value + shift : value }
  end

  def query_vector
    @query_vector ||= DummyEmbeddings.vector_for(text: QUERY)
  end

  def user_named(label)
    User.create!(
      name: label,
      email: "#{label}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
  end

  def unique_name(label)
    "#{label} #{SecureRandom.hex(4)}"
  end

  def capture_logs
    io = StringIO.new
    previous = Rails.logger
    Rails.logger = Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = previous
  end
end
