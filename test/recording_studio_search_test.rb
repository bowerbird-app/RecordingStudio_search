# frozen_string_literal: true

require "test_helper"

class RecordingStudioSearchTest < Minitest::Test
  def test_version_matches_release
    assert_equal "0.7.0", ::RecordingStudioSearch::VERSION
  end

  def test_engine_exists
    assert_kind_of Class, ::RecordingStudioSearch::Engine
  end

  def test_gemspec_pins_recording_studio_4_7
    gemspec = File.read(File.expand_path("../recording_studio_search.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio", ">= 4.7.0"'
    assert_includes gemspec, 'spec.add_dependency "pgvector"'
    assert_includes gemspec, 'spec.add_dependency "json", ">= 2.21", "< 3"'
  end

  def test_gemspec_excludes_cursor_config
    spec = Gem::Specification.load(File.expand_path("../recording_studio_search.gemspec", __dir__))
    cursor_files = spec.files.select { |path| path == ".cursor" || path.split("/").include?(".cursor") }

    assert_empty cursor_files, "gemspec must not package .cursor/ (got #{cursor_files.inspect})"
  end

  def test_cursor_environment_is_repo_managed_without_snapshot
    path = File.expand_path("../.cursor/environment.json", __dir__)
    json = JSON.parse(File.read(path))

    assert_equal "recording-studio-search", json["name"]
    assert_equal ".cursor/install.sh", json["install"]
    assert_equal ".cursor/start.sh", json["start"]
    refute json.key?("snapshot"), "snapshot pins a Personal build and skips install"
    refute json.key?("agentCanUpdateSnapshot")
  end

  def test_cursor_install_still_fetches_skills
    install_script = File.read(File.expand_path("../.cursor/install.sh", __dir__))

    assert_includes install_script, "fetch-skills.sh"
  end

  def test_dummy_gemfile_pins_verified_4x_github_tags
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))
    root_gemfile = File.read(File.expand_path("../Gemfile", __dir__))

    assert_includes root_gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v4.7.0"'

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v4.7.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.17.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.9.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.2.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.10.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_cache", tag: "v0.5.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_users", tag: "v0.21.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_admin", tag: "v2.3.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.15.0"'
    assert_includes gemfile, 'github: "bowerbird-app/flatpack", tag: "v0.1.213"'
    refute_includes gemfile, "recording_studio/v3.0.0"
    refute_includes gemfile, 'tag: "v0.1.133"'
    refute_includes gemfile, 'tag: "v0.1.134"'
    refute_includes gemfile, 'tag: "0.3.1"'
  end

  def test_dummy_accesses_schema_includes_depends_on_recording_id
    structure = File.read(File.expand_path("dummy/db/structure.sql", __dir__))

    assert_includes structure, "depends_on_recording_id"
  end

  def test_template_does_not_ship_copied_core_hooks_or_base_service
    refute File.exist?(File.expand_path("../lib/recording_studio_search/hooks.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_search/services/base_service.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_search/services/example_service.rb", __dir__))
  end

  def test_example_capability_wraps_include_for_and_is_not_enabled_globally
    source = File.read(File.expand_path("../lib/recording_studio_search/capabilities/example.rb", __dir__))

    assert_includes source, "def self.to(**)"
    assert_includes source, "RecordingStudio::Capabilities.include_for(:example, **)"
    refute_includes source, "enable_capability"
    refute_includes source, "set_capability_options"
    refute RecordingStudio.capability_enabled?(:example, for: "Folder")
    refute RecordingStudio.capability_enabled?(:example, for: "Page")
    assert_empty RecordingStudio.configuration.enabled_recordable_types_for(:example)
  end

  def test_dummy_app_uses_recording_studio_default_layout
    application_controller_path = File.expand_path("dummy/app/controllers/application_controller.rb", __dir__)
    controller_source = File.read(application_controller_path)

    assert_includes controller_source, "include RecordingStudio::UsesDefaultLayout"
    assert_includes controller_source, '"recording_studio/default_layout"'
    assert_includes controller_source, "devise_controller? ? \"application\""
    refute_includes controller_source, "flat_pack_sidebar"
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack_sidebar.html.erb", __dir__))
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__))
    refute File.exist?(File.expand_path("dummy/app/views/layouts/recording_studio/default_layout.html.erb", __dir__))
  end

  def test_dummy_host_names_the_rounded_flatpack_theme
    initializer = File.read(File.expand_path("dummy/config/initializers/flat_pack.rb", __dir__))
    html_theme = File.read(File.expand_path("dummy/config/initializers/html_rounded_theme.rb", __dir__))

    assert_includes initializer, "FlatPack.configure"
    assert_includes initializer, "default_theme = :rounded"
    assert_includes html_theme, "DummyHtmlRoundedTheme"
    assert_includes html_theme, 'data-theme="rounded"'
    refute_includes html_theme, "recording_studio/default_layout.html.erb"
  end

  def test_dummy_login_layout_keeps_flatpack_assets_without_tight_main_offset
    application_layout = File.read(File.expand_path("dummy/app/views/layouts/application.html.erb", __dir__))

    assert_includes application_layout, '<html data-theme="rounded">'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/variables"'
    assert_includes application_layout, "javascript_importmap_tags"
    assert_includes application_layout, "min-h-screen"
    refute_includes application_layout, "mt-28"
    refute_includes application_layout, "flat_pack_sidebar"
  end

  def test_dummy_tailwind_keeps_flatpack_theme_selection_in_flatpack
    tailwind_source = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))

    assert_includes tailwind_source, "../../../vendor/bundle/**/flatpack/app/components/**/*.{rb,erb}"
    assert_includes tailwind_source, "flatpack-*/app/components/**/*.{rb,erb}"
    assert_includes tailwind_source, "usr/local/lib/ruby/gems/**/bundler/gems/flatpack-"
    assert_includes tailwind_source, "../../../vendor/bundle/**/recording_studio/app/views/**/*.erb"
    assert_includes tailwind_source, "recordingstudio-*/app/views/**/*.erb"
    assert_includes tailwind_source, "usr/local/lib/ruby/gems/**/bundler/gems/RecordingStudio-"
    refute_includes tailwind_source, "@theme"
    refute_includes tailwind_source, ":root {"
    refute_includes tailwind_source, "--color-fp-primary"
  end

  def test_recording_studio_keeps_strict_recordable_declarations_enabled
    initializer_path = File.expand_path("dummy/config/initializers/recording_studio.rb", __dir__)
    initializer_source = File.read(initializer_path)

    assert_includes initializer_source, "config.require_recordable_declarations = true"
    assert_includes initializer_source, "RecordingStudioUser::People"
    assert_includes initializer_source, "RecordingStudioUser::Profile"
    assert_includes initializer_source, "RecordingStudioAttachable::Attachment"
    refute_includes initializer_source, "config.include_children"
    refute_includes initializer_source, "config.features."
    refute_includes initializer_source, "v3"
  end

  def test_dummy_readme_explains_dummy_app_purpose
    readme_path = File.expand_path("dummy/README.md", __dir__)
    readme_source = File.read(readme_path)

    assert_includes readme_source, "validate the Recording Studio search addon"
    assert_includes readme_source, "/recording_studio"
    assert_includes readme_source, "redirects to `/`"
    assert_includes readme_source, "html data-theme=\"rounded\""
    assert_includes readme_source, "default_theme = :rounded"
    assert_includes readme_source, "/people"
    assert_includes readme_source, "/instant"
    assert_includes readme_source, "/groups"
    assert_includes readme_source, "/title-first"
    refute_includes readme_source, "flat_pack_sidebar"
  end

  def test_product_readme_is_the_search_guide
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "RecordingStudio"
    assert_includes readme, "searchable"
    assert_includes readme, "pg_trgm"
    assert_includes readme, "pgvector"
    assert_includes File.read(File.expand_path("../docs/search-plan.md", __dir__)), "## Phase 4 — Instant search UI"
    assert_includes readme, "One model, one page"
    assert_includes readme, "User.search"
    assert_includes readme, "instant_search_field"
    assert_includes readme, "instant_search_results"
    assert_includes readme, "instant_search_models"
    assert_includes readme, "trigram or vector"
    assert_includes readme, "recording_studio_search_queries"
    refute_includes readme, "v3 declarations"
    refute_includes readme, "RecordingStudio v3"
    refute_includes readme, "ExampleService"
    refute_includes readme, "recording_studio/v3.0.0"
  end

  def test_dummy_home_page_is_the_search_demo
    view_path = File.expand_path("dummy/app/views/home/index.html.erb", __dir__)
    view_source = File.read(view_path)

    assert_includes view_source, 'title: "Search"'
    assert_includes view_source, "FlatPack::Search::Component"
    assert_includes view_source, "max_width: :none"
    assert_includes view_source, "size: :lg"
    refute_includes view_source, "max_width: :lg"
    assert_includes view_source, "dummy_page_nav"
    assert_includes view_source, "dummy_search_demo_buttons"
    refute_includes view_source, "FlatPack::TextInput::Component"
    refute_includes view_source, "Look up"
    refute_includes view_source, 'title: "Template Demo"'
    refute_includes view_source, "FlatPack::Breadcrumb::Component"
  end

  def test_dummy_people_page_searches_one_model
    controller = File.read(File.expand_path("dummy/app/controllers/people_controller.rb", __dir__))
    view_source = File.read(File.expand_path("dummy/app/views/people/index.html.erb", __dir__))

    assert_includes controller, "User.search"
    refute_includes controller, "RecordingStudioSearch.search"
    assert_includes view_source, "people_path"
    assert_includes view_source, "FlatPack::Search::Component"
    refute_includes view_source, "Pages"
    refute_includes view_source, "Notes"
  end

  def test_dummy_group_and_title_first_pages_demo_scope_and_weights
    groups_controller = File.read(File.expand_path("dummy/app/controllers/group_searches_controller.rb", __dir__))
    groups_view = File.read(File.expand_path("dummy/app/views/group_searches/index.html.erb", __dir__))
    weights_controller = File.read(File.expand_path("dummy/app/controllers/weighted_pages_controller.rb", __dir__))
    weights_view = File.read(File.expand_path("dummy/app/views/weighted_pages/index.html.erb", __dir__))
    routes = File.read(File.expand_path("dummy/config/routes.rb", __dir__))

    assert_includes groups_controller, "people.search"
    assert_includes groups_controller, "email ILIKE"
    assert_includes groups_view, "groups_path"
    assert_includes groups_view, "In this group"
    assert_includes weights_controller, "TrigramSearcher"
    assert_includes weights_view, "title_first_path"
    assert_includes weights_view, "Title first"
    assert_includes routes, 'get "groups"'
    assert_includes routes, 'get "title-first"'
  end

  def test_dummy_home_demo_buttons_link_to_people_groups_and_title_first
    helper = File.read(File.expand_path("dummy/app/helpers/application_helper.rb", __dir__))

    assert_includes helper, "people_path"
    assert_includes helper, "instant_people_path"
    assert_includes helper, "groups_path"
    assert_includes helper, "title_first_path"
    assert_includes helper, "Just people"
    assert_includes helper, "As you type"
    assert_includes helper, "In a group"
    assert_includes helper, "Title first"
  end

  def test_dummy_instant_page_uses_locked_helper_and_engine_frame
    controller = File.read(File.expand_path("dummy/app/controllers/instant_people_controller.rb", __dir__))
    view_source = File.read(File.expand_path("dummy/app/views/instant_people/index.html.erb", __dir__))
    routes = File.read(File.expand_path("dummy/config/routes.rb", __dir__))

    assert_includes controller, "User.none"
    assert_includes view_source, "instant_search_field"
    assert_includes view_source, "instant_search_results"
    assert_includes view_source, 'frame_id: "people_results"'
    assert_includes view_source, "recording_studio_search.instant_search_path"
    refute_includes view_source, "<turbo-frame"
    assert_includes routes, "instant_people"
    assert_includes routes, "RecordingStudioSearch::Engine"
  end

  def test_dummy_docs_pages_use_minimal_flatpack_documentation_components
    docs_view_paths = Dir[File.expand_path("dummy/app/views/docs/*.html.erb", __dir__)].reject do |view_path|
      File.basename(view_path).start_with?("_")
    end
    refute_empty docs_view_paths

    docs_view_paths.each do |view_path|
      view_source = File.read(view_path)

      assert_includes view_source, "dummy_page_nav"
      assert_includes view_source, "FlatPack::PageTitle::Component"
      refute_includes view_source, "FlatPack::Card::Component"
      refute_includes view_source, "FlatPack::Breadcrumb::Component"
    end

    methods_view = File.read(File.expand_path("dummy/app/views/docs/methods.html.erb", __dir__))
    assert_includes methods_view, "FlatPack::SectionTitle::Component"
    assert_includes methods_view, "FlatPack::CodeBlock::Component"
    assert_includes methods_view, "User.search"
    assert_includes methods_view, "RecordingStudioSearch.search"
    assert_includes methods_view, "Scope"
    assert_includes methods_view, "against: { title: \"A\", body: \"D\" }"
    assert_includes methods_view, "/groups"
    assert_includes methods_view, "/title-first"

    gem_views_view = File.read(File.expand_path("dummy/app/views/docs/gem_views.html.erb", __dir__))
    assert_includes gem_views_view, "FlatPack::Table::Component"
    refute_includes gem_views_view, "FlatPack::List::Component"

    recordable_types_view = File.read(File.expand_path("dummy/app/views/docs/recordable_types.html.erb", __dir__))
    assert_includes recordable_types_view, "FlatPack::List::Component"
    refute_includes recordable_types_view, "v3 parent/root"

    recordings_tree_view = File.read(File.expand_path("dummy/app/views/docs/recordings_tree.html.erb", __dir__))
    assert_includes recordings_tree_view, "FlatPack::Tree::Component"
    refute_includes recordings_tree_view, "Current structure"
    refute_includes recordings_tree_view, "This tree is generated from RecordingStudio::Recording records"
  end

  def test_dummy_recordings_tree_view_omits_structure_section_copy
    recordings_tree_view = File.read(File.expand_path("dummy/app/views/docs/recordings_tree.html.erb", __dir__))

    assert_includes recordings_tree_view, 'title: "Recordings tree"'
    assert_includes recordings_tree_view, "FlatPack::Tree::Component"
    recording_tree_partial = File.read(File.expand_path("dummy/app/views/docs/_recording_tree_node.html.erb", __dir__))
    assert_includes recording_tree_partial, "parent_builder.node"
    refute_includes recordings_tree_view, "Current structure"
    refute_includes recordings_tree_view, "This tree is generated from RecordingStudio::Recording records"
  end

  def test_engine_does_not_ship_a_home_view
    view_path = File.expand_path("../app/views/recording_studio_search/home/index.html.erb", __dir__)

    refute File.exist?(view_path)
  end
end
