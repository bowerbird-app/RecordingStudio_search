# frozen_string_literal: true

require "test_helper"

class ResultFilterTest < ActiveSupport::TestCase
  QUERY = "refund"

  setup do
    RecordingStudioSearch.reset_result_filters!
    @owner = User.create!(
      name: "Filter Owner",
      email: "filter-owner-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!"
    )
    @viewer = User.create!(
      name: "Filter Viewer",
      email: "filter-viewer-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!"
    )
    @root = DummyAccess.bootstrap_workspace!(
      name: "Filter Workspace #{SecureRandom.hex(4)}",
      actor: @owner
    )
    @ada = User.create!(name: "Ada Lovelace", email: "ada-#{SecureRandom.hex(4)}@example.com", password: "Password123!")
    @grace = User.create!(
      name: "Grace Lovelace",
      email: "grace-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!"
    )
  end

  teardown do
    RecordingStudioSearch.reset_result_filters!
  end

  test "trigram search applies the filter before the limit" do
    assert_equal 2, User.search("Lovelace", unscoped: true).count

    first = User.search("Lovelace", limit: 1, unscoped: true).first
    other = first.id == @ada.id ? @grace : @ada
    hide_user(first)

    sqls = capture_sql do
      assert_equal [other.id], User.search("Lovelace", limit: 1, unscoped: true).map(&:id)
    end
    user_selects = sqls.select { |sql| sql.match?(/FROM "users"/i) && sql.match?(/\A\s*SELECT/i) }

    assert_equal 1, user_selects.size
    assert_match(/\bLIMIT\b/i, user_selects.first)
    assert_equal [other.id], RecordingStudioSearch.search(User, "Lovelace", limit: 1, unscoped: true).map(&:id)
    assert_equal [other.id], RecordingStudioSearch::TrigramSearcher.call(User.all, "Lovelace", limit: 1).map(&:id)
  end

  test "reloading the same registration does not stack filters" do
    2.times { hide_user(@ada) }

    assert_equal 1, RecordingStudioSearch::ResultFilters.count_for(User)
    ids = User.search("Lovelace", unscoped: true).map(&:id)
    refute_includes ids, @ada.id
    assert_includes ids, @grace.id
  end

  test "blank query keeps the filter inside the relation" do
    hide_user(@ada)

    ids = User.search("", unscoped: true).map(&:id)

    refute_includes ids, @ada.id
    assert_includes ids, @grace.id
  end

  test "a filter must return the same model's relation" do
    RecordingStudioSearch.register_result_filter(User) { |_relation| nil }

    assert_raises(ArgumentError) { User.search("Lovelace", unscoped: true).load }
  end

  test "a filter cannot widen the access scope" do
    with_folder_grants do
      visible_folder = place_folder!("Visible", @root)
      hidden_folder = place_folder!("Hidden", @root)
      visible = place_page!("Visible refund policy", visible_folder)
      hidden = place_page!("Hidden refund policy", hidden_folder)
      grant_view!(visible_folder)
      embed!(visible)
      embed!(hidden)

      RecordingStudioSearch.register_result_filter(Page) { |_relation| Page.all }
      visible_ids = Page.search(QUERY, actor: @viewer, root: @root, limit: 20).map(&:id)
      instant = RecordingStudioSearch::InstantSearch.hits_for(
        ["Page"], QUERY, actor: @viewer, root: @root, limit: 20
      )

      assert_includes visible_ids, visible.recordable_id
      refute_includes visible_ids, hidden.recordable_id
      assert_includes instant.map(&:id), visible.recordable_id
      refute_includes instant.map(&:id), hidden.recordable_id

      RecordingStudioSearch.reset_result_filters!
      RecordingStudioSearch.register_result_filter(Page) { |relation| relation.unscope(where: :id) }
      unscoped_ids = Page.search(QUERY, actor: @viewer, root: @root, limit: 20).map(&:id)

      assert_includes unscoped_ids, visible.recordable_id
      refute_includes unscoped_ids, hidden.recordable_id

      RecordingStudioSearch.reset_result_filters!
      RecordingStudioSearch.register_result_filter(Page) { |_relation| Page.where(id: hidden.recordable_id) }
      replaced_ids = Page.search(QUERY, actor: @viewer, root: @root, limit: 20).map(&:id)

      refute_includes replaced_ids, hidden.recordable_id
      refute_includes replaced_ids, visible.recordable_id
    end
  end

  test "vector search and instant search apply the filter before the limit" do
    near = place_page!("Near refund policy", @root)
    far = place_page!("Far refund policy", @root)
    embed!(near)
    embed!(far)
    RecordingStudioSearch::Document.find_by!(recording_id: near.id).update!(embedding: shifted_vector(0.0))
    RecordingStudioSearch::Document.find_by!(recording_id: far.id).update!(embedding: shifted_vector(0.5))

    assert_equal [near.recordable_id], Page.search(QUERY, actor: @owner, root: @root, limit: 1).map(&:id)

    RecordingStudioSearch.register_result_filter(Page) do |relation|
      relation.where.not(id: near.recordable_id)
    end

    sqls = capture_sql do
      assert_equal [far.recordable_id], Page.search(QUERY, actor: @owner, root: @root, limit: 1).map(&:id)
    end
    document_sql = sqls.find { |sql| sql.include?("recording_studio_search_documents") && sql.match?(/\bLIMIT\b/i) }

    assert document_sql, sqls.inspect
    assert_match(/searchable_id/i, document_sql)
    assert_match(/IN\s*\(\s*SELECT/i, document_sql)
    assert_match(/root_recording_id/i, document_sql)
    assert_match(/recording_id/i, document_sql)

    instant = RecordingStudioSearch::InstantSearch.hits_for(
      ["Page"], QUERY, actor: @owner, root: @root, limit: 1
    )
    assert_equal [far.recordable_id], instant.map(&:id)

    direct = RecordingStudioSearch::EmbeddingSearcher.call(
      RecordingStudioSearch::AccessibleScope.relation_for(Page, @owner, root: @root),
      QUERY,
      limit: 1,
      root_recording_id: @root.id,
      recording_ids: RecordingStudioSearch::AccessibleScope.recording_ids_for(
        @owner, root: @root, recordable_type: "Page"
      )
    )
    assert_equal [far.recordable_id], direct.map(&:id)
  end

  private

  def hide_user(user)
    RecordingStudioSearch.register_result_filter(User) do |relation|
      relation.where.not(id: user.id)
    end
  end

  def capture_sql
    sqls = []
    callback = lambda do |*, payload|
      sqls << payload[:sql].to_s
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    sqls
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

  def place_folder!(name, parent)
    folder = Folder.create!(name: "#{name} #{SecureRandom.hex(3)}")
    DummyAccess.as_actor(@owner) do
      RecordingStudio.record!(
        action: "created",
        recordable: folder,
        root_recording: @root,
        parent_recording: parent
      ).recording
    end
  end

  def place_page!(title, parent)
    page = Page.create!(title: title, body: "How to request a refund when a charge looks wrong.")
    DummyAccess.as_actor(@owner) do
      RecordingStudio.record!(
        action: "created",
        recordable: page,
        root_recording: @root,
        parent_recording: parent
      ).recording
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
