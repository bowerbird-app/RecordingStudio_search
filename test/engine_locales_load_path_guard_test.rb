# frozen_string_literal: true

require "test_helper"

class EngineLocalesLoadPathGuardTest < Minitest::Test
  def test_engine_does_not_mutate_i18n_load_path
    engine_source = File.read(File.expand_path("../lib/recording_studio_search/engine.rb", __dir__))

    refute_includes engine_source, "i18n.load_path"
    refute_includes engine_source, "I18n.load_path"
  end
end
