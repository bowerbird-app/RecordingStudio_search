# frozen_string_literal: true

module RecordingStudioSearch
  module Schema
    COLUMN_NAME = /\A[a-zA-Z_][a-zA-Z0-9_]*\z/
    WEIGHTS = %w[A B C D].freeze
    RANK_SCALE = { "A" => 1.0, "B" => 0.4, "C" => 0.2, "D" => 0.1 }.freeze
    EMBED_REPEATS = { "A" => 4, "B" => 3, "C" => 2, "D" => 1 }.freeze

    Field = Data.define(:column, :weight)

    module_function

    def parse_against(value)
      fields(value).map(&:column)
    end

    def fields(value)
      if value.is_a?(Hash)
        value.map { |column, weight| field_for(column, weight) }
      else
        Array(value).flat_map { |item| item.to_s.split(",") }.map(&:strip).reject(&:empty?).map do |item|
          column, weight = item.split(":", 2)
          field_for(column, weight)
        end
      end
    end

    def field_for(column, weight)
      name = column.to_s.strip
      validate_column!(name)
      Field.new(column: name, weight: parse_weight(weight))
    end

    def parse_weight(weight)
      return if weight.nil? || weight.to_s.strip.empty?

      parsed = weight.to_s.strip.upcase
      return parsed if WEIGHTS.include?(parsed)

      raise ArgumentError, "Invalid search weight #{weight.inspect} (use A, B, C, or D)"
    end

    def validate_column!(name)
      return if name.match?(COLUMN_NAME)

      raise ArgumentError, "Invalid search column #{name.inspect}"
    end

    def tsvector_expression(against)
      parsed = fields(against)
      if parsed.any?(&:weight)
        parsed.map do |field|
          weight = field.weight || "D"
          "setweight(to_tsvector('english', coalesce(#{field.column}::text, '')), '#{weight}')"
        end.join(" || ")
      else
        parts = parsed.map { |field| "coalesce(#{field.column}::text, '')" }
        "to_tsvector('english', #{parts.join(" || ' ' || ")})"
      end
    end
  end
end
