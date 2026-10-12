# frozen_string_literal: true

require "test_helper"

class EngineLocalesLoadPathGuardTest < Minitest::Test
  def test_lib_does_not_mutate_i18n_load_path
    lib_root = File.expand_path("../lib", __dir__)
    ruby_files = Dir[File.join(lib_root, "**", "*.rb")]

    assert_operator ruby_files.size, :>, 0, "expected lib/**/*.rb files to scan"

    ruby_files.each do |path|
      source = File.read(path)
      relative = path.delete_prefix("#{lib_root}/")

      refute_includes source, "i18n.load_path",
                      "#{relative} must not mutate i18n.load_path"
      refute_includes source, "I18n.load_path",
                      "#{relative} must not mutate I18n.load_path"
    end
  end
end
