# frozen_string_literal: true

require "test_helper"

class ExampleCapabilityTest < Minitest::Test
  def test_example_capability_is_gone
    refute File.exist?(File.expand_path("../../lib/recording_studio_search/capabilities/example.rb", __dir__))
    refute File.exist?(File.expand_path("../../lib/recording_studio_search/capabilities", __dir__))
    source = File.read(File.expand_path("../../lib/recording_studio_search.rb", __dir__))

    refute_includes source, "capabilities/example"
    refute_includes source, "Capabilities::Example"
    refute RecordingStudio.registered_capabilities.key?(:example)
    refute defined?(RecordingStudio::Capabilities::Example)
  end
end
