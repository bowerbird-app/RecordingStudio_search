# frozen_string_literal: true

require "test_helper"
require "stringio"
require "logger"

class DocumentEmbedderTest < Minitest::Test
  class ProbeRecord
    class << self
      attr_accessor :instance

      def find_by(id:)
        instance if instance&.id.to_s == id.to_s
      end
    end

    attr_reader :id

    def initialize(id:)
      @id = id
    end

    def recording_studio_search_text
      "probe body"
    end
  end

  class FakeDocuments
    class << self
      attr_accessor :create_error, :existing

      def find_by(**)
        existing
      end

      def create!(*)
        raise create_error if create_error

        :created
      end
    end
  end

  class ProbeEmbedder < RecordingStudioSearch::DocumentEmbedder
    def documents
      FakeDocuments
    end
  end

  def setup
    @original_client = RecordingStudioSearch.configuration.embedding_client
    RecordingStudioSearch.configuration.embedding_client = lambda { |**|
      [0.1, 0.2]
    }
    ProbeRecord.instance = ProbeRecord.new(id: 11)
    FakeDocuments.existing = nil
    FakeDocuments.create_error = nil
  end

  def teardown
    RecordingStudioSearch.configuration.embedding_client = @original_client
    ProbeRecord.instance = nil
    FakeDocuments.existing = nil
    FakeDocuments.create_error = nil
  end

  def test_adapter_error_is_logged_and_not_raised
    RecordingStudioSearch.configuration.embedding_client = lambda { |**|
      raise RecordingStudioSearch::EmbeddingAdapter::Error, "upstream"
    }

    logs = with_embed_logger { embedder.call }

    assert_match(/embed failed model=DocumentEmbedderTest::ProbeRecord/, logs)
    assert_match(/EmbeddingAdapter::Error: upstream/, logs)
  end

  def test_record_invalid_is_logged_and_not_raised
    FakeDocuments.create_error = ActiveRecord::RecordInvalid.new

    logs = with_embed_logger { embedder.call }

    assert_match(/ActiveRecord::RecordInvalid/, logs)
    assert_match(/embed failed/, logs)
  end

  def test_record_not_unique_is_logged_and_not_raised
    FakeDocuments.create_error = ActiveRecord::RecordNotUnique.new("duplicate")

    logs = with_embed_logger { embedder.call }

    assert_match(/ActiveRecord::RecordNotUnique: duplicate/, logs)
  end

  def test_statement_invalid_is_logged_and_not_raised
    FakeDocuments.create_error = ActiveRecord::StatementInvalid.new("bad sql")

    logs = with_embed_logger { embedder.call }

    assert_match(/ActiveRecord::StatementInvalid: bad sql/, logs)
  end

  def test_argument_error_from_create_is_not_swallowed
    FakeDocuments.create_error = ArgumentError.new("not an embed write error")

    error = assert_raises(ArgumentError) { embedder.call }
    assert_equal "not an embed write error", error.message
  end

  def test_successful_create_is_not_logged_as_failure
    logs = with_embed_logger { embedder.call }

    refute_match(/embed failed/, logs)
  end

  private

  def embedder
    ProbeEmbedder.new(
      searchable_type: "DocumentEmbedderTest::ProbeRecord",
      searchable_id: 11
    )
  end

  def with_embed_logger
    io = StringIO.new
    previous = Rails.logger
    Rails.logger = Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = previous
  end
end
