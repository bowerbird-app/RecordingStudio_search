# frozen_string_literal: true

require "test_helper"

class AccessibleSearchScopeTest < ActiveSupport::TestCase
  QUERY = "refund"

  AccessGrant = Struct.new(:actor) do
    def authorize!(recording:, role:, **)
      allowed = recording.present? &&
                RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: role)
      return if allowed

      raise "API access grant is not authorized for this capability"
    end
  end

  Context = Struct.new(:access_grant, :root_recording, :params, keyword_init: true)

  setup do
    @owner = User.create!(
      name: "Scope Owner",
      email: "scope-owner-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!"
    )
    @viewer = User.create!(
      name: "Scope Viewer",
      email: "scope-viewer-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!"
    )
    @root = DummyAccess.bootstrap_workspace!(
      name: "Scope Workspace #{SecureRandom.hex(4)}",
      actor: @owner
    )
  end

  test "scoped search omits recordings the actor cannot view and trashed recordings" do
    with_folder_grants do
      visible_folder = place_folder!("Visible", @root)
      hidden_folder = place_folder!("Hidden", @root)
      visible = place_page!("Visible refund policy", visible_folder)
      hidden = place_page!("Hidden refund policy", hidden_folder)
      trashed = place_page!("Trashed refund policy", visible_folder)
      trash!(trashed)
      grant_view!(visible_folder)
      embed!(visible)
      embed!(hidden)
      embed!(trashed)
      RecordingStudioSearch::Document.find_by!(recording_id: hidden.id).update!(embedding: shifted_vector(0.0))
      RecordingStudioSearch::Document.find_by!(recording_id: visible.id).update!(embedding: shifted_vector(0.5))

      scoped = Page.search(QUERY, actor: @viewer, root: @root, limit: 1)
      trigram = RecordingStudioSearch::TrigramSearcher.call(
        RecordingStudioSearch::AccessibleScope.relation_for(Page, @viewer, root: @root),
        QUERY,
        limit: 20
      )

      assert_equal [visible.recordable_id], scoped.map(&:id)
      assert_includes trigram.map(&:id), visible.recordable_id
      refute_includes trigram.map(&:id), hidden.recordable_id
      refute_includes trigram.map(&:id), trashed.recordable_id

      sql = trigram.to_sql
      assert_match(/WITH RECURSIVE/i, sql)
      assert_match(/\bLIMIT\b/i, sql)
      assert_operator sql.scan(/[0-9a-f]{8}-[0-9a-f]{4}-/).size, :<, 8

      opened = Page.search(QUERY, limit: 20, unscoped: true).map(&:id)
      assert_includes opened, hidden.recordable_id
      assert_includes opened, trashed.recordable_id
    end
  end

  test "instant search and search.query use a constant number of queries as the tree grows" do
    page = place_page!("Counted refund policy", place_folder!("Shallow", @root))
    embed!(page)
    Page.search(QUERY, actor: @owner, root: @root, limit: 1).load

    before = measure_search
    20.times { |index| place_folder!("Extra #{index}", @root) }
    after = measure_search

    assert_equal [page.recordable_id], instant_hits.map(&:id)
    assert_equal before, after
    assert_operator after.fetch(:instant), :<, 20
    assert_operator after.fetch(:query), :<, 25
    assert_operator after.fetch(:trigram), :<, 12
  end

  test "search fails closed when authorized recording ids are unsupported" do
    page = place_page!("Unsupported refund policy", @root)
    called = false

    RecordingStudioAccessible.stub(:authorized_recording_ids_supported?, false) do
      RecordingStudioAccessible.stub(:authorized_recording_ids, lambda { |**|
        called = true
        raise RecordingStudioAccessible::Error, "unsupported"
      }) do
        hits = Page.search(QUERY, actor: @owner, root: @root, limit: 5).to_a
        instant = RecordingStudioSearch::InstantSearch.hits_for(
          ["Page"], QUERY, actor: @owner, root: @root
        )

        assert_empty hits
        assert_empty Array(instant)
        refute_includes hits.map(&:id), page.recordable_id
      end
    end

    refute called
  end

  test "search requires an actor and root unless unscoped is set" do
    error = assert_raises(ArgumentError) { Page.search(QUERY) }
    assert_match(/unscoped: true/, error.message)

    assert_raises(ArgumentError) { RecordingStudioSearch.search(Page, QUERY, actor: @owner) }
    assert_raises(ArgumentError) { User.search(QUERY, root: @root) }
    assert_empty Page.search(QUERY, actor: @viewer, root: @root)
  end

  private

  def measure_search
    {
      instant: statement_count { instant_hits },
      query: statement_count { api_hits },
      trigram: statement_count { trigram_hits }
    }
  end

  def instant_hits
    RecordingStudioSearch::InstantSearch.hits_for(
      ["Page"], QUERY, actor: @owner, root: @root, limit: 5
    ).to_a
  end

  def api_hits
    RecordingStudioSearch::Api::Query.call(
      Context.new(
        access_grant: AccessGrant.new(@owner),
        root_recording: @root,
        params: { q: QUERY, models: ["Page"], limit: "5" }
      )
    ).fetch(:hits)
  end

  def trigram_hits
    RecordingStudioSearch::TrigramSearcher.call(
      RecordingStudioSearch::AccessibleScope.relation_for(Page, @owner, root: @root),
      QUERY,
      limit: 5
    ).to_a
  end

  def statement_count
    count = 0
    callback = lambda do |*, payload|
      next if payload[:cached]
      next if payload[:name] == "SCHEMA"

      sql = payload[:sql].to_s
      next if sql.match?(/\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE|SET |SHOW )\b/i)

      count += 1
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    count
  end

  def place_folder!(name, parent)
    folder = Folder.create!(name: "#{name} #{SecureRandom.hex(3)}")
    place!(folder, parent)
  end

  def place_page!(title, parent)
    page = Page.create!(title: title, body: "How to request a refund when a charge looks wrong.")
    place!(page, parent)
  end

  def place!(recordable, parent)
    DummyAccess.as_actor(@owner) do
      RecordingStudio.record!(
        action: "created",
        recordable: recordable,
        root_recording: @root,
        parent_recording: parent
      ).recording
    end
  end

  def with_folder_grants
    RecordingStudio.enable_capability(:accessible, on: Folder)
    yield
  ensure
    RecordingStudio.synchronize_capabilities do
      enabled = RecordingStudio.configuration.instance_variable_get(:@capabilities)
      enabled["Folder"]&.delete(:accessible)
      enabled.delete("Folder") if enabled["Folder"].blank?
    end
  end

  def grant_view!(recording)
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: @viewer,
      role: :view,
      manager_actor: @owner
    )
    raise result.error if result.failure?

    result
  end

  def trash!(recording)
    recording.update_columns(trashed_at: Time.current)
  end

  def embed!(recording)
    RecordingStudioSearch::DocumentEmbedder.call(
      searchable_type: recording.recordable_type,
      searchable_id: recording.recordable_id,
      recording_id: recording.id
    )
  end

  def shifted_vector(shift)
    DummyEmbeddings.vector_for(text: QUERY).each_with_index.map do |value, index|
      index.zero? ? value + shift : value
    end
  end
end
