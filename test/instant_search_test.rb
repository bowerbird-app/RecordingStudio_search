# frozen_string_literal: true

require "test_helper"

class InstantSearchTest < Minitest::Test
  def setup
    @original = RecordingStudioSearch.instance_variable_get(:@configuration)
    RecordingStudioSearch.reset_configuration!
  end

  def teardown
    RecordingStudioSearch.instance_variable_set(:@configuration, @original)
  end

  def test_empty_allowlist_rejects_every_requested_model
    RecordingStudioSearch.configuration.instant_search_models = []

    assert_empty RecordingStudioSearch::InstantSearch.allowed_models(["User", String])
  end

  def test_allowlist_keeps_only_requested_models_that_are_listed
    RecordingStudioSearch.configuration.instant_search_models = [String, Integer]

    assert_equal [String], RecordingStudioSearch::InstantSearch.allowed_models(%w[String File])
    assert_equal [String, Integer], RecordingStudioSearch::InstantSearch.allowed_models([String, Integer])
  end

  def test_allowlist_ignores_unknown_and_unsafe_names
    RecordingStudioSearch.configuration.instant_search_models = ["String"]

    assert_empty RecordingStudioSearch::InstantSearch.allowed_models(%w[Kernel Nope::Missing])
    assert_equal [String], RecordingStudioSearch::InstantSearch.allowed_models("String")
  end

  def test_search_param_defaults_to_q_and_rejects_reserved_keys
    assert_equal "q", RecordingStudioSearch::InstantSearch.search_param({})
    assert_equal "q", RecordingStudioSearch::InstantSearch.search_param({ param: "models" })
    assert_equal "q", RecordingStudioSearch::InstantSearch.search_param({ param: "frame_id" })
    assert_equal "query", RecordingStudioSearch::InstantSearch.search_param({ param: "query" })
  end

  def test_hits_for_blank_query_or_empty_allowlist_is_empty
    RecordingStudioSearch.configuration.instant_search_models = []

    assert_equal({}, RecordingStudioSearch::InstantSearch.hits_for(["User"], "Ada"))
    assert_equal({}, RecordingStudioSearch::InstantSearch.hits_for(["User"], "   "))
  end

  def test_configuration_to_h_lists_allowlist_names
    RecordingStudioSearch.configuration.instant_search_models = [String]

    assert_equal ["String"], RecordingStudioSearch.configuration.to_h.fetch(:instant_search_models)
  end
end
