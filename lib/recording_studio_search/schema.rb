# frozen_string_literal: true

module RecordingStudioSearch
  module Schema
    COLUMN_NAME = /\A[a-zA-Z_][a-zA-Z0-9_]*\z/

    module_function

    def parse_against(value)
      Array(value).flat_map { |item| item.to_s.split(",") }.map(&:strip).reject(&:empty?).tap do |columns|
        columns.each { |column| validate_column!(column) }
      end
    end

    def validate_column!(name)
      return if name.match?(COLUMN_NAME)

      raise ArgumentError, "Invalid search column #{name.inspect}"
    end

    def tsvector_expression(columns)
      parts = parse_against(columns).map { |column| "coalesce(#{column}::text, '')" }
      "to_tsvector('english', #{parts.join(" || ' ' || ")})"
    end
  end
end
