# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_search/install/install_generator"

class InstallGeneratorTest < Minitest::Test
  INSTALL_TEMPLATE_PATH = File.expand_path(
    "../lib/generators/recording_studio_search/install/templates/INSTALL.md",
    __dir__
  )

  def with_temp_app
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "config/initializers"))
      FileUtils.mkdir_p(File.join(dir, "db/migrate"))
      yield dir
    end
  end

  def build_generator(destination_root, options = {})
    RecordingStudioSearch::Generators::InstallGenerator.new(
      [],
      options,
      destination_root: destination_root
    )
  end

  def test_copy_initializer_writes_search_settings
    with_temp_app do |dir|
      generator = build_generator(dir)
      generator.stub(:say, nil) do
        generator.copy_initializer
      end

      contents = File.read(File.join(dir, "config/initializers/recording_studio_search.rb"))
      assert_includes contents, "config.default_backend = :pg_trgm"
      assert_includes contents, "config.embedding_client = nil"
      assert_includes contents, "config.trigram_threshold = 0.3"
      assert_includes contents, "config.instant_search_models = []"
      refute_includes contents, "API_KEY"
    end
  end

  def test_copy_migrations_invokes_migrations_generator
    generator = build_generator("/tmp")
    invoked = []

    generator.stub(:invoke, ->(name) { invoked << name }) do
      generator.copy_migrations
    end

    assert_equal ["recording_studio_search:migrations"], invoked
  end

  def test_show_readme_displays_install_guide_for_invoke_behavior
    generator = build_generator("/tmp")
    shown_templates = []

    generator.stub(:behavior, :invoke) do
      generator.stub(:readme, ->(template) { shown_templates << template }) do
        generator.show_readme
      end
    end

    assert_equal ["INSTALL.md"], shown_templates
  end

  def test_install_guide_covers_per_model_generators
    install_guide = File.read(INSTALL_TEMPLATE_PATH)

    assert_includes install_guide, "bin/rails db:migrate"
    assert_includes install_guide, "searchable_pg_trgm"
    assert_includes install_guide, "searchable_pgvector"
    assert_includes install_guide, "embedding_client"
    assert_includes install_guide, "instant_search_models"
    assert_includes install_guide, "InstantSearchesController#show"
    refute_includes install_guide, "RecordingStudio v3"
  end

  def test_mount_engine_adds_the_instant_search_route
    generator = build_generator("/tmp")
    routes = []

    generator.stub(:route, ->(line) { routes << line }) do
      generator.mount_engine
    end

    assert_equal ['mount RecordingStudioSearch::Engine, at: "/recording_studio_search"'], routes
  end

  def test_add_importmap_entries_pins_and_eager_loads_stimulus
    with_temp_app do |dir|
      FileUtils.mkdir_p(File.join(dir, "app/javascript/controllers"))
      File.write(File.join(dir, "config/importmap.rb"), "pin \"application\"\n")
      File.write(
        File.join(dir, "app/javascript/controllers/index.js"),
        "import { application } from \"controllers/application\"\nimport { eagerLoadControllersFrom } from \"@hotwired/stimulus-loading\"\n"
      )

      generator = build_generator(dir)
      generator.stub(:say, nil) do
        generator.add_importmap_entries
      end

      importmap = File.read(File.join(dir, "config/importmap.rb"))
      index_js = File.read(File.join(dir, "app/javascript/controllers/index.js"))

      assert_includes importmap, "controllers/recording_studio_search"
      assert_includes index_js, 'eagerLoadControllersFrom("controllers/recording_studio_search", application)'
    end
  end
end
