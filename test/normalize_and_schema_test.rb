# frozen_string_literal: true

require "test_helper"

class NormalizeAndSchemaTest < Minitest::Test
  def test_keyword_normalizes_case_and_space
    assert_equal "refund policy", RecordingStudioSearch::Normalize.keyword("  Refund   POLICY ")
  end

  def test_vector_literal
    assert_equal "[0.1,1.0]", RecordingStudioSearch::Normalize.vector_literal([0.1, 1])
  end

  def test_tsvector_expression
    expression = RecordingStudioSearch::Schema.tsvector_expression(%w[name email])
    assert_equal "to_tsvector('english', coalesce(name::text, '') || ' ' || coalesce(email::text, ''))", expression
  end

  def test_tsvector_expression_with_weights
    expression = RecordingStudioSearch::Schema.tsvector_expression({ title: "A", body: "D" })
    assert_equal(
      "setweight(to_tsvector('english', coalesce(title::text, '')), 'A') || " \
      "setweight(to_tsvector('english', coalesce(body::text, '')), 'D')",
      expression
    )
  end

  def test_parse_against_accepts_weighted_generator_string
    assert_equal %w[title body], RecordingStudioSearch::Schema.parse_against("title:A,body:D")
  end

  def test_rejects_invalid_column_names
    assert_raises(ArgumentError) { RecordingStudioSearch::Schema.parse_against(["name;drop"]) }
  end

  def test_rejects_invalid_weights
    assert_raises(ArgumentError) { RecordingStudioSearch::Schema.parse_against({ title: "Z" }) }
  end
end
