# frozen_string_literal: true

require "test_helper"

class RegistryAndSearchableTest < Minitest::Test
  def setup
    RecordingStudioSearch::Registry.reset!
  end

  def teardown
    RecordingStudioSearch::Registry.reset!
  end

  def test_registers_two_models_with_different_backends
    user = Class.new do
      def self.name = "UserProbe"
    end
    page = Class.new do
      def self.name = "PageProbe"
    end

    RecordingStudioSearch::Registry.register(user, backend: :pg_trgm, against: %i[name email])
    RecordingStudioSearch::Registry.register(page, backend: :pgvector, against: %i[title body],
                                                   recording_id: :search_recording_id)

    assert_equal :pg_trgm, RecordingStudioSearch::Registry.entry_for(user).backend
    assert_equal :pgvector, RecordingStudioSearch::Registry.entry_for(page).backend
    assert_equal :search_recording_id, RecordingStudioSearch::Registry.entry_for(page).recording_id_method
    assert_equal({}, RecordingStudioSearch::Registry.entry_for(user).weights)
    assert_equal 1, RecordingStudioSearch::Registry.pgvector_entries.size
  end

  def test_registers_weights_from_against_hash
    page = Class.new do
      def self.name = "WeightedPageProbe"
    end
    RecordingStudioSearch::Registry.register(page, backend: :pg_trgm, against: { title: "A", body: "D" })

    entry = RecordingStudioSearch::Registry.entry_for(page)
    assert_equal %i[title body], entry.against
    assert_equal({ title: "A", body: "D" }, entry.weights)
  end

  def test_searchable_rejects_invalid_weight
    klass = Class.new do
      include RecordingStudioSearch::Searchable

      def self.name = "BadWeight"
      def self.after_commit(*) = nil
    end

    assert_raises(ArgumentError) do
      klass.searchable(backend: :pg_trgm, against: { title: "E" })
    end
  end

  def test_pgvector_without_client_is_treated_as_trigram
    model = Class.new do
      def self.name = "VectorProbe"
    end
    RecordingStudioSearch::Registry.register(model, backend: :pgvector, against: %i[title])
    RecordingStudioSearch.reset_configuration!

    assert_equal :pg_trgm, RecordingStudioSearch.effective_backend_for(model)
  end

  def test_searchable_rejects_unknown_backend
    klass = Class.new do
      include RecordingStudioSearch::Searchable

      def self.name = "BadBackend"
      def self.after_commit(*) = nil
    end

    assert_raises(ArgumentError) do
      klass.searchable(backend: :elasticsearch, against: %i[title])
    end
  end
end
