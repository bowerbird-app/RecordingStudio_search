# frozen_string_literal: true

require "test_helper"
require "logger"
require "minitest/mock"
require "psych"
require "stringio"

class EngineTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioSearch.instance_variable_get(:@configuration)
    RecordingStudioSearch.instance_variable_set(:@configuration, RecordingStudioSearch::Configuration.new)
  end

  def teardown
    RecordingStudioSearch.configuration.hooks.clear!
    RecordingStudioSearch.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_before_and_after_initialize_initializers_run_hooks
    before_called = false
    after_called = false

    RecordingStudioSearch.configuration.hooks.before_initialize { |_engine| before_called = true }
    RecordingStudioSearch.configuration.hooks.after_initialize { |_engine| after_called = true }

    find_initializer("recording_studio_search.before_initialize").block.call(Object.new)
    find_initializer("recording_studio_search.after_initialize").block.call(Object.new)

    assert before_called
    assert after_called
  end

  def test_load_config_merges_config_sources_and_runs_on_configuration_hook
    hook_called = false
    hook_payload = nil
    RecordingStudioSearch.configuration.hooks.on_configuration do |cfg|
      hook_called = true
      hook_payload = cfg
    end

    xcfg = Struct.new(:recording_studio_search).new({ vector_result_limit: 9 })
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        { embedding_model: "from_yaml", trigram_threshold: 0.12 }
      end
    end.new(app_config)

    find_initializer("recording_studio_search.load_config").block.call(app)

    assert hook_called
    assert_equal RecordingStudioSearch.configuration, hook_payload
    assert_equal "from_yaml", RecordingStudioSearch.configuration.embedding_model
    assert_in_delta 0.12, RecordingStudioSearch.configuration.trigram_threshold
    assert_equal 9, RecordingStudioSearch.configuration.vector_result_limit
  end

  def test_load_config_handles_errors_and_each_pair_fallback
    pair_config = Class.new do
      def each_pair
        yield(:trigram_threshold, 0.15)
      end
    end.new

    xcfg = Struct.new(:recording_studio_search).new(pair_config)
    app_config = Struct.new(:x).new(xcfg)

    app = Struct.new(:config) do
      def config_for(_name)
        raise "missing file"
      end
    end.new(app_config)

    logs = with_engine_logger do
      find_initializer("recording_studio_search.load_config").block.call(app)
    end

    assert_in_delta 0.15, RecordingStudioSearch.configuration.trigram_threshold
    assert_match(/skipped host YAML config \(RuntimeError: missing file\)/, logs)
  end

  def test_load_config_logs_psych_syntax_errors_from_yaml
    app_config = Struct.new(:x).new(Object.new)
    app = Struct.new(:config) do
      def config_for(_name)
        raise Psych::SyntaxError.new("<unknown>", 1, 1, 0, "mapping", nil)
      end
    end.new(app_config)

    logs = with_engine_logger do
      find_initializer("recording_studio_search.load_config").block.call(app)
    end

    assert_equal "text-embedding-3-small", RecordingStudioSearch.configuration.embedding_model
    assert_match(/skipped host YAML config \(Psych::SyntaxError/, logs)
  end

  def test_load_config_does_not_rescue_argument_error_from_yaml
    app = Struct.new(:config) do
      def config_for(_name)
        raise ArgumentError, "not a host config miss"
      end
    end.new(Object.new)

    error = assert_raises(ArgumentError) do
      find_initializer("recording_studio_search.load_config").block.call(app)
    end
    assert_equal "not a host config miss", error.message
  end

  def test_load_config_swallow_each_pair_errors
    bad_pair_config = Class.new do
      def each_pair
        raise "bad pair"
      end
    end.new

    xcfg = Struct.new(:recording_studio_search).new(bad_pair_config)
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        { embedding_model: "ok" }
      end
    end.new(app_config)

    logs = with_engine_logger do
      find_initializer("recording_studio_search.load_config").block.call(app)
    end

    assert_equal "ok", RecordingStudioSearch.configuration.embedding_model
    assert_match(/skipped host config\.x config \(RuntimeError: bad pair\)/, logs)
  end

  def test_load_config_logs_nomethod_error_from_each_pair
    bad_pair_config = Class.new do
      def each_pair
        raise NoMethodError, "undefined method 'to_sym' for nil"
      end
    end.new

    xcfg = Struct.new(:recording_studio_search).new(bad_pair_config)
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        { embedding_model: "ok" }
      end
    end.new(app_config)

    logs = with_engine_logger do
      find_initializer("recording_studio_search.load_config").block.call(app)
    end

    assert_equal "ok", RecordingStudioSearch.configuration.embedding_model
    assert_match(/skipped host config\.x config \(NoMethodError/, logs)
  end

  def test_load_config_is_noop_without_config_sources
    app = Struct.new(:config).new(Object.new)

    find_initializer("recording_studio_search.load_config").block.call(app)

    assert_equal "text-embedding-3-small", RecordingStudioSearch.configuration.embedding_model
    assert_in_delta 0.3, RecordingStudioSearch.configuration.trigram_threshold
    assert_equal 50, RecordingStudioSearch.configuration.vector_result_limit
  end

  def test_load_config_ignores_non_enumerable_yaml_and_merge_errors
    yaml = Class.new do
      def each
        raise "bad yaml"
      end
    end.new

    xcfg = Struct.new(:recording_studio_search).new({ trigram_threshold: 0.22 })
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      attr_accessor :yaml

      def config_for(_name)
        @yaml
      end
    end.new(app_config)
    app.yaml = yaml

    find_initializer("recording_studio_search.load_config").block.call(app)

    assert_in_delta 0.22, RecordingStudioSearch.configuration.trigram_threshold
  end

  def test_apply_extension_initializers_register_active_support_on_load_callbacks
    to_prepare_blocks = []
    config_stub = Object.new
    config_stub.define_singleton_method(:to_prepare) do |&block|
      to_prepare_blocks << block
    end

    RecordingStudioSearch::Engine.stub(:config, config_stub) do
      find_initializer("recording_studio_search.apply_model_extensions").block.call
      find_initializer("recording_studio_search.apply_controller_extensions").block.call
    end

    assert_equal 2, to_prepare_blocks.size
  end

  def test_model_extension_initializer_skips_abstract_models
    abstract_model = Class.new do
      def self.abstract_class?
        true
      end
    end
    concrete_model = Class.new do
      def self.abstract_class?
        false
      end
    end

    assert_equal [concrete_model],
                 RecordingStudioSearch::Engine.concrete_models([abstract_model, concrete_model])
  end

  def test_controller_extension_initializer_applies_all_controllers
    first_controller = Class.new do
      def self.name
        "FirstController"
      end
    end
    second_controller = Class.new do
      def self.name
        "SecondController"
      end
    end
    RecordingStudioSearch.configuration.hooks.extend_controller(:FirstController) do
      def first_extension
        :first
      end
    end
    RecordingStudioSearch.configuration.hooks.extend_controller(:SecondController) do
      def second_extension
        :second
      end
    end

    RecordingStudioSearch::Engine.apply_controller_extensions(first_controller)
    RecordingStudioSearch::Engine.apply_controller_extensions(second_controller)

    assert_equal :first, first_controller.new.first_extension
    assert_equal :second, second_controller.new.second_extension
  end

  def test_apply_model_extensions_adds_registered_methods_once
    model_class = Class.new do
      def self.name
        "ExampleRecord"
      end
    end

    RecordingStudioSearch.configuration.hooks.extend_model(:ExampleRecord) do
      def template_extension_method
        :applied
      end
    end

    RecordingStudioSearch::Engine.apply_model_extensions(model_class)
    RecordingStudioSearch::Engine.apply_model_extensions(model_class)

    instance = model_class.new
    assert_equal :applied, instance.template_extension_method
  end

  def test_apply_controller_extensions_matches_demodulized_name
    controller_class = Class.new do
      def self.name
        "Admin::DashboardController"
      end
    end

    RecordingStudioSearch.configuration.hooks.extend_controller(:DashboardController) do
      def template_controller_extension
        :applied
      end
    end

    RecordingStudioSearch::Engine.apply_controller_extensions(controller_class)

    instance = controller_class.new
    assert_equal :applied, instance.template_controller_extension
  end

  def test_apply_extensions_flattens_compacts_and_tracks_identity
    target = Class.new
    extension = proc do
      def generated_method
        :generated
      end
    end

    RecordingStudioSearch::Engine.send(:apply_extensions, target, [nil, [extension, extension]])

    assert_equal :generated, target.new.generated_method
    assert_equal true, target.instance_variable_get(:@recording_studio_search_applied_extensions).compare_by_identity?
  end

  def test_apply_extensions_returns_without_target
    assert_nil RecordingStudioSearch::Engine.send(:apply_extensions, nil, [])
  end

  def test_extension_keys_for_includes_demodulized_name
    namespaced = Class.new do
      def self.name
        "Admin::ReportsController"
      end
    end

    expected_keys = [:"Admin::ReportsController"]
    expected_keys << :ReportsController

    assert_equal expected_keys, RecordingStudioSearch::Engine.send(:extension_keys_for, namespaced)
  end

  def test_extension_keys_for_removes_duplicate_names
    plain = Class.new do
      def self.name
        "ReportsController"
      end
    end

    assert_equal [:ReportsController], RecordingStudioSearch::Engine.send(:extension_keys_for, plain)
  end

  def test_register_shipped_english_initializer_is_ordered_before_base_load
    initializer = find_initializer("recording_studio_search.register_shipped_english")

    refute_nil initializer, "engine must declare register_shipped_english"
    assert_equal "recording_studio.load_shipped_english", initializer.before
    # Do not call initializer.block here. Boot-time registration is asserted in
    # the dummy suite (EnglishFallbackTest) so the path check can fail on its own
    # when the register line is removed.
  end

  private

  def with_engine_logger
    io = StringIO.new
    previous = Rails.logger
    Rails.logger = Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = previous
  end

  def find_initializer(name)
    RecordingStudioSearch::Engine.initializers.find { |initializer| initializer.name == name }
  end
end
