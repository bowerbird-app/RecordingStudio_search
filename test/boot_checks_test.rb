# frozen_string_literal: true

require "test_helper"

class BootChecksTest < Minitest::Test
  def setup
    RecordingStudioSearch::Registry.reset!
    RecordingStudioSearch.reset_configuration!
  end

  def teardown
    RecordingStudioSearch::Registry.reset!
    RecordingStudioSearch.reset_configuration!
  end

  def test_missing_embeddings_for_pgvector_warns_once
    model = Class.new do
      def self.name = "VectorOnly"
      def self.table_exists? = false
    end
    RecordingStudioSearch::Registry.register(model, backend: :pgvector, against: %i[title])

    io = StringIO.new
    previous = Rails.logger
    Rails.logger = Logger.new(io)

    RecordingStudioSearch::BootChecks.run
    RecordingStudioSearch::BootChecks.run

    messages = io.string
    assert_equal 1, messages.scan("treating them as trigram until fixed").size
  ensure
    Rails.logger = previous
  end
end
