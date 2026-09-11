# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RecordingStudioSearch
  module Generators
    class SearchablePgTrgmGenerator < Rails::Generators::NamedBase
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Add search_vector and trigram indexes to a model table"

      class_option :against, type: :string, required: true,
                             desc: "Comma-separated columns, optionally column:A through column:D"

      def add_trigram_migration
        @against_columns = RecordingStudioSearch::Schema.parse_against(options[:against])
        @tsvector_expression = RecordingStudioSearch::Schema.tsvector_expression(options[:against])
        @table = table_name
        migration_template(
          "add_search_vector.rb.tt",
          File.join("db/migrate", "add_search_vector_to_#{table_name}.rb")
        )
      end

      attr_reader :tsvector_expression, :against_columns, :table
    end
  end
end
