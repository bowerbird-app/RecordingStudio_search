# frozen_string_literal: true

require "test_helper"

class PageVectorSearchTest < ActiveSupport::TestCase
  setup do
    RecordingStudioSearch::Document.delete_all
    RecordingStudioSearch::Query.delete_all
    Page.delete_all
    @refund = Page.create!(title: "Refunds", body: "How to request a refund when a charge looks wrong.")
    @password = Page.create!(title: "Passwords", body: "Set a password you can remember.")
    embed(@refund)
    embed(@password)
  end

  test "vector search returns embedding hits only" do
    titles = Page.search("refund").map(&:title)
    assert_includes titles, "Refunds"
    refute_includes titles, "Passwords"
  end

  test "query cache hit skips the embedding client" do
    Page.search("refund")
    calls = 0
    RecordingStudioSearch.configuration.embedding_client = lambda { |text:, model:|
      calls += 1
      DummyEmbeddings.vector_for(text: text, model: model)
    }

    Page.search("refund")
    assert_equal 0, calls
    query = RecordingStudioSearch::Query.find_by!(keyword: "refund")
    assert query.hit_count >= 1
  ensure
    RecordingStudioSearch.configuration.embedding_client = DummyEmbeddings.method(:vector_for)
  end

  test "cache miss stores a query row" do
    assert_difference -> { RecordingStudioSearch::Query.count }, 1 do
      Page.search("password reset")
    end
    stored = RecordingStudioSearch::Query.find_by!(keyword: "password reset")
    assert_equal "text-embedding-3-small", stored.embedding_model
    assert_equal 8, stored.embedding.size
  end

  test "ai error falls back to trigram and warns" do
    RecordingStudioSearch.configuration.embedding_client = lambda { |text:, model:|
      raise RecordingStudioSearch::EmbeddingAdapter::Error, "upstream"
    }

    logs = capture_logs { @titles = Page.search("Refunds").map(&:title) }
    assert_includes @titles, "Refunds"
    assert_match(/falling back to trigram/, logs)
    assert_match(/Page/, logs)
  ensure
    RecordingStudioSearch.configuration.embedding_client = DummyEmbeddings.method(:vector_for)
  end

  test "empty documents fall back to trigram and warn" do
    RecordingStudioSearch::Document.delete_all

    logs = capture_logs { @titles = Page.search("refund").map(&:title) }
    assert_includes @titles, "Refunds"
    assert_match(/cold start/, logs)
  end

  test "documents upsert by recording_id and skip unchanged digest" do
    page = Page.create!(title: "Stable identity", body: "refund wording")
    workspace = Workspace.create!(name: "Search Root")
    user = User.create!(name: "Embedder", email: "embed-#{SecureRandom.hex(4)}@example.com", password: "Password")
    previous = Current.actor
    Current.actor = user
    root = RecordingStudio.root_recording_for(workspace)
    recording = RecordingStudio.record!(
      action: "created",
      recordable: page,
      root_recording: root,
      parent_recording: root
    ).recording
    Current.actor = previous

    RecordingStudioSearch::DocumentEmbedder.call(
      searchable_type: "Page",
      searchable_id: page.id,
      recording_id: recording.id
    )
    first = RecordingStudioSearch::Document.find_by!(recording_id: recording.id)
    assert_equal page.id, first.searchable_id

    RecordingStudioSearch::DocumentEmbedder.call(
      searchable_type: "Page",
      searchable_id: page.id,
      recording_id: recording.id
    )
    assert_equal 1, RecordingStudioSearch::Document.where(recording_id: recording.id).count
    assert_equal first.content_digest, RecordingStudioSearch::Document.find_by!(recording_id: recording.id).content_digest
  end

  test "model table has no embedding columns" do
    refute Page.column_names.include?("embedding")
    refute Page.column_names.include?("embedding_at")
    refute Page.column_names.include?("embedding_model")
  end

  test "embed job enqueues and logs adapter failure" do
    page = Page.create!(title: "Job page", body: "refund job")
    assert_enqueued_with(job: RecordingStudioSearch::EmbedDocumentJob) do
      RecordingStudioSearch.embed_later(page)
    end

    RecordingStudioSearch.configuration.embedding_client = lambda { |text:, model:|
      raise RecordingStudioSearch::EmbeddingAdapter::Error, "nope"
    }
    logs = capture_logs do
      RecordingStudioSearch::EmbedDocumentJob.perform_now(
        searchable_type: "Page",
        searchable_id: page.id
      )
    end
    assert_match(/embed failed/, logs)
  ensure
    RecordingStudioSearch.configuration.embedding_client = DummyEmbeddings.method(:vector_for)
  end

  test "notes stay on trigram after being enabled later" do
    Note.delete_all
    Note.create!(title: "Sticky reminder")
    assert_includes Note.search("sticky").map(&:title), "Sticky reminder"
  end

  private

  def embed(record)
    RecordingStudioSearch::DocumentEmbedder.call(
      searchable_type: record.class.name,
      searchable_id: record.id
    )
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
