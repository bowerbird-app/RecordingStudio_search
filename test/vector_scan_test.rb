# frozen_string_literal: true

require "test_helper"

class VectorScanTest < Minitest::Test
  def test_iterative_scans_start_at_pgvector_0_8
    assert RecordingStudioSearch::VectorScan.iterative?(connection_with("0.8.0"))
    assert RecordingStudioSearch::VectorScan.iterative?(connection_with("0.8.1"))
    assert RecordingStudioSearch::VectorScan.iterative?(connection_with("0.8"))
    refute RecordingStudioSearch::VectorScan.iterative?(connection_with("0.7.4"))
    refute RecordingStudioSearch::VectorScan.iterative?(connection_with("0.6.0"))
    refute RecordingStudioSearch::VectorScan.iterative?(connection_with(nil))
  end

  def test_pgvector_0_8_enables_strict_iterative_hnsw_scans
    connection = connection_with("0.8.1")

    RecordingStudioSearch::VectorScan.apply!(connection, iterative: true)

    assert_includes connection.sql, "SET LOCAL hnsw.iterative_scan = strict_order"
    assert_includes connection.sql, "SET LOCAL hnsw.max_scan_tuples = 100000"
    assert_includes connection.sql, "SET LOCAL hnsw.scan_mem_multiplier = 2"
    refute_includes connection.sql.join("\n"), "enable_indexscan"
  end

  def test_older_pgvector_uses_an_exact_filtered_scan
    connection = connection_with("0.6.0")

    RecordingStudioSearch::VectorScan.apply!(connection, iterative: false)
    RecordingStudioSearch::VectorScan.restore!(connection, iterative: false)

    assert_includes connection.sql, "SET LOCAL enable_indexscan = off"
    assert_includes connection.sql, "SET LOCAL enable_bitmapscan = off"
    assert_includes connection.sql, "SET LOCAL enable_indexscan = on"
    assert_includes connection.sql, "SET LOCAL enable_bitmapscan = on"
    refute_includes connection.sql.join("\n"), "hnsw.iterative_scan"
  end

  private

  def connection_with(version)
    Connection.new(version)
  end

  class Connection
    def initialize(version)
      @version = version
      @sql = []
    end

    attr_reader :sql

    def select_value(_statement)
      @version
    end

    def execute(statement)
      @sql << statement
    end
  end
end
