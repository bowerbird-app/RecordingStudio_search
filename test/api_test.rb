# frozen_string_literal: true

require "test_helper"
require "recording_studio_api"

class ApiTest < Minitest::Test
  class FakeGrant
    def initialize(actor:, authorized: true)
      @actor = actor
      @authorized = authorized
    end

    attr_reader :actor

    def authorize!(recording:, role:, **)
      raise "API access grant is not authorized for this capability" unless @authorized
      raise "view role required" unless role == :view
      raise "root recording required" if recording.nil?
    end
  end

  class FakeRoot
    def id
      1
    end
  end

  class FakeContext
    def initialize(actor:, params: {}, root_recording: FakeRoot.new, authorized: true)
      @access_grant = FakeGrant.new(actor: actor, authorized: authorized)
      @params = params
      @root_recording = root_recording
    end

    attr_reader :access_grant, :params, :root_recording
  end

  class FakeHits
    def initialize(records)
      @records = records
    end

    def blank?
      @records.empty?
    end

    def klass
      FakePage
    end

    def where(*)
      self
    end

    def none
      self.class.new([])
    end

    def to_ary
      @records
    end
  end

  class FakePage
    TYPE = "page"
  end

  def setup
    @original = RecordingStudioSearch.instance_variable_get(:@configuration)
    RecordingStudioSearch.reset_configuration!
    RecordingStudioSearch.configuration.instant_search_models = [FakePage]
  end

  def teardown
    RecordingStudioSearch.instance_variable_set(:@configuration, @original)
  end

  def test_register_is_a_noop_when_api_is_unavailable
    RecordingStudioSearch::Api.stub(:available?, false) do
      assert_nil RecordingStudioSearch::Api.register!
    end
  end

  def test_gemspec_omits_runtime_recording_studio_api_dependency
    gemspec = File.read(File.expand_path("../recording_studio_search.gemspec", __dir__))
    gemfile = File.read(File.expand_path("../Gemfile", __dir__))

    refute_includes gemspec, 'spec.add_dependency "recording_studio_api"'
    refute_includes gemspec, 'spec.add_development_dependency "recording_studio_api"'
    assert_includes gemfile, "recording_studio_api"
  end

  def test_engine_registers_api_when_present
    engine = File.read(File.expand_path("../lib/recording_studio_search/engine.rb", __dir__))
    api = File.read(File.expand_path("../lib/recording_studio_search/api.rb", __dir__))
    query = File.read(File.expand_path("../lib/recording_studio_search/api/query.rb", __dir__))

    assert_includes engine, 'initializer "recording_studio_search.api"'
    assert_includes engine, "RecordingStudioSearch::Api.register!"
    assert_includes api, "RecordingStudioApi.register_endpoint"
    assert_includes api, "return unless available?"
    assert_includes api, "NAME = \"search.query\""
    assert_includes api, "handler: Query"
    assert_includes api, "http_verb: :get"
    assert_includes api, "path: PATH"
    assert_includes api, "PATH = \"search/query\""
    assert_includes api, 'title: "Search - Query"'
    assert_includes api, 'summary: "Search - Query"'
    assert_includes api, "not paginated"
    refute_includes api, "register_capability_action"
    refute File.exist?(File.expand_path("../lib/recording_studio_search/mcp.rb", __dir__))
    assert_includes query, "grant.authorize!"
    assert_includes query, "InstantSearch.hits_for"
    assert_includes query, "actor: grant.actor"
    assert_includes query, "root_recording_id"
    refute_includes query, "Pundit"
  end

  def test_search_query_registration_is_idempotent
    registrations = []
    RecordingStudioApi.stub(:registered_endpoint, ->(*) { registrations.first }) do
      RecordingStudioApi.stub(:register_endpoint, lambda { |name, **options|
        registrations << { name: name, **options }
      }) do
        2.times { RecordingStudioSearch::Api.register! }
      end
    end

    names = registrations.map { |entry| entry.fetch(:name) }
    assert_equal ["search.query"], names
    registration = registrations.first
    assert_equal :get, registration.fetch(:http_verb)
    assert_equal "search/query", registration.fetch(:path)
    assert_equal RecordingStudioSearch::Api::Query, registration.fetch(:handler)
  end

  def test_query_returns_hits_when_authorized
    page = Struct.new(:id).new("page-1")
    hits = FakeHits.new([page])
    captured = {}

    RecordingStudioSearch::InstantSearch.stub(:hits_for, lambda { |models, query, **kwargs|
      captured[:models] = models
      captured[:query] = query
      captured[:actor] = kwargs[:actor]
      captured[:limit] = kwargs[:limit]
      hits
    }) do
      RecordingStudioSearch.stub(:recording_id_for, "rec-1") do
        RecordingStudioSearch::Api::Query.stub(:relation_in_root, ->(relation, *) { relation }) do
          payload = RecordingStudioSearch::Api::Query.call(
            FakeContext.new(actor: :owner, params: { q: "refund", models: ["FakePage"], limit: "5" })
          )

          assert_equal [{ type: "ApiTest::FakePage", id: "page-1", recording_id: "rec-1" }], payload.fetch(:hits)
        end
      end
    end

    assert_equal ["FakePage"], captured[:models]
    assert_equal "refund", captured[:query]
    assert_equal :owner, captured[:actor]
    assert_equal 5, captured[:limit]
  end

  def test_query_denies_unauthorized_callers
    error = assert_raises(RuntimeError) do
      RecordingStudioSearch::Api::Query.call(
        FakeContext.new(actor: :stranger, params: { q: "refund" }, authorized: false)
      )
    end

    assert_match(/not authorized/, error.message)
  end

  def test_query_defaults_models_to_the_allowlist
    captured = nil
    RecordingStudioSearch::InstantSearch.stub(:hits_for, lambda { |models, *_rest, **|
      captured = models
      FakeHits.new([])
    }) do
      RecordingStudioSearch::Api::Query.call(FakeContext.new(actor: :owner, params: { q: "refund" }))
    end

    assert_equal ["ApiTest::FakePage"], captured
  end

  def test_query_returns_no_hits_when_root_is_missing
    page = Struct.new(:id).new("page-1")
    hits = FakeHits.new([page])

    RecordingStudioSearch::InstantSearch.stub(:hits_for, hits) do
      payload = RecordingStudioSearch::Api::Query.call(
        FakeContext.new(actor: :owner, params: { q: "refund" }, root_recording: Object.new)
      )

      assert_equal [], payload.fetch(:hits)
    end
  end

  def test_query_returns_no_hits_when_root_is_nil
    page = Struct.new(:id).new("page-1")
    hits = FakeHits.new([page])

    scoped = RecordingStudioSearch::Api::Query.send(:in_root, hits, nil)

    assert_equal [], scoped.to_ary
  end
end
