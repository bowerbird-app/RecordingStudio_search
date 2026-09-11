# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RecordingStudioSearch
  module Generators
    class SearchablePgvectorGenerator < Rails::Generators::NamedBase
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Enable trigram fallback plus shared pgvector documents for a model"

      class_option :against, type: :string, required: true,
                             desc: "Comma-separated columns, optionally column:A through column:D"

      def ensure_trigram
        if trigram_migration_exists?
          say "skip  search_vector on #{table_name} (already generated)", :yellow
        else
          invoke "recording_studio_search:searchable_pg_trgm", [name], against: options[:against]
        end
      end

      def ensure_documents_migration
        if documents_migration_exists?
          say "skip  recording_studio_search_documents (already generated)", :yellow
          return
        end

        @embedding_dimensions = RecordingStudioSearch.configuration.embedding_dimensions
        migration_template(
          "create_documents.rb.tt",
          File.join("db/migrate", "create_recording_studio_search_documents.rb")
        )
      end

      attr_reader :embedding_dimensions

      private

      def trigram_migration_exists?
        Dir.glob(File.join(destination_root, "db/migrate", "*add_search_vector_to_#{table_name}*")).any?
      end

      def documents_migration_exists?
        Dir.glob(File.join(destination_root, "db/migrate", "*create_recording_studio_search_documents*")).any?
      end
    end
  end
end
