# frozen_string_literal: true

module RecordingStudioSearch
  # Filtered HNSW scans return too few rows unless pgvector walks the index
  # again after the root predicate. 0.8.0 added iterative scans. Older
  # extensions still filter before LIMIT, by sorting the matching rows exactly.
  class VectorScan
    ITERATIVE_VERSION = Gem::Version.new("0.8.0")
    MAX_SCAN_TUPLES = 100_000
    DEFAULT_MAX_SCAN_TUPLES = 20_000
    SCAN_MEM_MULTIPLIER = 2
    DEFAULT_SCAN_MEM_MULTIPLIER = 1

    def self.apply!(connection, iterative:)
      if iterative
        connection.execute("SET LOCAL hnsw.iterative_scan = strict_order")
        connection.execute("SET LOCAL hnsw.max_scan_tuples = #{Integer(MAX_SCAN_TUPLES)}")
        connection.execute("SET LOCAL hnsw.scan_mem_multiplier = #{Integer(SCAN_MEM_MULTIPLIER)}")
      else
        connection.execute("SET LOCAL enable_indexscan = off")
        connection.execute("SET LOCAL enable_bitmapscan = off")
      end
    end

    def self.restore!(connection, iterative:)
      if iterative
        connection.execute("SET LOCAL hnsw.iterative_scan = off")
        connection.execute("SET LOCAL hnsw.max_scan_tuples = #{Integer(DEFAULT_MAX_SCAN_TUPLES)}")
        connection.execute("SET LOCAL hnsw.scan_mem_multiplier = #{Integer(DEFAULT_SCAN_MEM_MULTIPLIER)}")
      else
        connection.execute("SET LOCAL enable_indexscan = on")
        connection.execute("SET LOCAL enable_bitmapscan = on")
      end
    end

    def self.iterative?(connection)
      version = extension_version(connection)
      version.present? && version >= ITERATIVE_VERSION
    end

    def self.extension_version(connection)
      raw = connection.select_value("SELECT extversion FROM pg_extension WHERE extname = 'vector'")
      parse_version(raw)
    end

    def self.parse_version(raw)
      return if raw.blank?

      match = raw.to_s[/\d+(?:\.\d+){0,3}/]
      return if match.blank?

      Gem::Version.new(match)
    rescue ArgumentError
      nil
    end
  end
end
