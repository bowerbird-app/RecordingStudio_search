# frozen_string_literal: true

require_relative "lib/recording_studio_search/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_search"
  spec.version     = RecordingStudioSearch::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_search"
  spec.summary     = "Postgres trigram and optional vector search for Recording Studio hosts"
  spec.description = "A Rails engine that adds opt-in Postgres search to ActiveRecord models: " \
                     "pg_trgm/full-text by default, and optional pgvector embeddings stored off the tree."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"].reject do |path|
      path == ".cursor" || path.start_with?(".cursor/")
    end
  end

  spec.add_dependency "json", ">= 2.21", "< 3"
  spec.add_dependency "pgvector", ">= 0.3"
  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
end
