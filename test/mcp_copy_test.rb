# frozen_string_literal: true

require "test_helper"

class McpCopyTest < Minitest::Test
  def test_tool_names_is_search_workspace
    assert_equal %w[search_workspace], RecordingStudioSearch::McpCopy.tool_names
  end

  def test_register_is_a_noop_when_mcp_is_unavailable
    RecordingStudioSearch::McpCopy.stub(:available?, false) do
      assert_nil RecordingStudioSearch::McpCopy.register!
    end
  end

  def test_register_is_a_noop_when_register_tool_is_missing
    mcp = Module.new

    RecordingStudioSearch::McpCopy.stub(:mcp, mcp) do
      RecordingStudioSearch::McpCopy.stub(:endpoint_registered?, true) do
        refute_respond_to mcp, :register_tool
        assert_nil RecordingStudioSearch::McpCopy.register!
      end
    end
  end

  def test_register_is_a_noop_when_the_search_query_endpoint_is_missing
    mcp = Module.new
    mcp.define_singleton_method(:register_tool) { |**| flunk "register_tool must not run" }

    RecordingStudioSearch::McpCopy.stub(:mcp, mcp) do
      RecordingStudioSearch::McpCopy.stub(:endpoint_registered?, false) do
        assert_nil RecordingStudioSearch::McpCopy.register!
      end
    end
  end

  def test_register_sends_named_tool_copy_to_mcp
    calls = []
    mcp = Module.new
    mcp.define_singleton_method(:register_tool) { |**registration| calls << registration }

    RecordingStudioSearch::McpCopy.stub(:mcp, mcp) do
      RecordingStudioSearch::McpCopy.stub(:endpoint_registered?, true) do
        RecordingStudioSearch::McpCopy.register!
        RecordingStudioSearch::McpCopy.register!
      end
    end

    assert_equal 2, calls.size
    registration = calls.first
    options = RecordingStudioSearch::McpCopy.search_tool_options
    assert_equal options, registration
    assert_equal "search_workspace", registration.fetch(:name)
    assert_equal :"search.query", registration.fetch(:endpoint)
    assert_equal "Search workspace", registration.fetch(:title)
    refute registration.key?(:type)
    refute registration.key?(:action)
    refute registration.key?(:operation)
    assert_equal RecordingStudioSearch::McpCopy::DESCRIPTION, registration.fetch(:description)
    assert_equal RecordingStudioSearch::Api::Q_DESCRIPTION, registration.dig(:input, "q", :description)
    assert_equal RecordingStudioSearch::Api::MODELS_DESCRIPTION, registration.dig(:input, "models", :description)
    assert_equal RecordingStudioSearch::Api::LIMIT_DESCRIPTION, registration.dig(:input, "limit", :description)
    assert_equal RecordingStudioSearch::McpCopy::OUTPUT, registration.fetch(:output)
  end

  def test_mcp_copy_does_not_mention_access
    description = RecordingStudioSearch::McpCopy::DESCRIPTION
    output = RecordingStudioSearch::McpCopy::OUTPUT

    refute_includes description, "Access"
    refute_includes description, "Accessible"
    refute_includes description, ":view"
    refute_includes description, ":edit"
    refute_includes description, "permission"
    refute_includes description.downcase, "role"
    refute_includes description, "Admin"
    refute_includes output, "Access"
    assert_includes description, "allowlisted types in this workspace"
    assert_includes description, "Returns the closest matches as hits"
    assert_includes description, "Required input is q"
    assert_includes description, "Each hit has type, id, and recording_id"
  end

  def test_gemspec_does_not_depend_on_recording_studio_mcp
    gemspec = File.read(File.expand_path("../recording_studio_search.gemspec", __dir__))
    entry = File.read(File.expand_path("../lib/recording_studio_search.rb", __dir__))
    engine = File.read(File.expand_path("../lib/recording_studio_search/engine.rb", __dir__))
    api = File.read(File.expand_path("../lib/recording_studio_search/api.rb", __dir__))
    gemfile = File.read(File.expand_path("../Gemfile", __dir__))

    refute_includes gemspec, "recording_studio_mcp"
    refute_includes gemfile, "recording_studio_mcp"
    refute_includes entry, 'require "recording_studio_mcp"'
    assert_includes entry, 'require "recording_studio_search/mcp_copy"'
    assert_includes engine,
                    'initializer "recording_studio_search.mcp", after: "recording_studio_search.api"'
    assert_includes engine, "RecordingStudioSearch::McpCopy.register!"
    refute_includes api, "register_capability_action"
    refute File.exist?(File.expand_path("../lib/recording_studio_search/mcp.rb", __dir__))
  end

  def test_readme_names_the_live_tool
    readme = File.read(File.expand_path("../README.md", __dir__))
    changelog = File.read(File.expand_path("../CHANGELOG.md", __dir__))

    assert_includes readme, "search_workspace"
    assert_includes readme, "McpCopy.tool_names"
    assert_includes changelog, "search_workspace"
    refute_includes readme, "This gem does not add MCP tool code."
  end
end
