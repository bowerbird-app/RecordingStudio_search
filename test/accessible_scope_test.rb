# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class AccessibleScopeTest < Minitest::Test
  FakeModel = Class.new do
    class << self
      def name
        "FakeModel"
      end

      def where(id:)
        [:scoped, id]
      end

      def none
        :none
      end
    end
  end

  def test_missing_accessible_is_empty
    RecordingStudioSearch::AccessibleScope.stub(:accessible?, false) do
      assert_equal :none, RecordingStudioSearch::AccessibleScope.relation_for(FakeModel, Object.new)
      assert_equal [], RecordingStudioSearch::AccessibleScope.recordings_for(Object.new)
      assert_equal [], RecordingStudioSearch::AccessibleScope.recordable_ids(FakeModel, Object.new)
    end
  end

  def test_blank_actor_is_empty
    RecordingStudioSearch::AccessibleScope.stub(:accessible?, true) do
      assert_equal :none, RecordingStudioSearch::AccessibleScope.relation_for(FakeModel, nil)
      assert_equal :none, RecordingStudioSearch::AccessibleScope.relation_for(FakeModel, "")
      assert_equal [], RecordingStudioSearch::AccessibleScope.recordings_for(nil)
      assert_equal [], RecordingStudioSearch::AccessibleScope.recordings_for("  ")
      assert_equal [], RecordingStudioSearch::AccessibleScope.recordable_ids(FakeModel, nil)
    end
  end

  def test_scope_uses_the_authorized_recording_id_relation
    source = File.read(File.expand_path("../lib/recording_studio_search/accessible_scope.rb", __dir__))

    assert_includes source, "authorized_recording_ids_supported?"
    assert_includes source, "authorized_recording_ids"
    assert_includes source, "trashed_at"
    refute_includes source, "root_recordings_for"
    refute_includes source, "RecordingStudioAccessible.recordings_for"
    refute_includes source, "RecordingStudioAccessible.authorized?"
  end
end
