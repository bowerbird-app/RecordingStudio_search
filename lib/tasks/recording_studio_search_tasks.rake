# frozen_string_literal: true

namespace :recording_studio_search do
  desc "Enqueue embeddings for every row on registered pgvector models"
  task backfill: :environment do
    RecordingStudioSearch::Registry.pgvector_entries.each do |entry|
      entry.model.find_each { |record| RecordingStudioSearch.embed_later(record) }
    end
  end

  desc "Clear cached query embeddings and documents, then backfill. Required after changing vector dimensions."
  task reembed: :environment do
    RecordingStudioSearch::Query.delete_all if RecordingStudioSearch::Query.table_exists?
    RecordingStudioSearch::Document.delete_all if RecordingStudioSearch::Document.table_exists?
    Rake::Task["recording_studio_search:backfill"].invoke
  end
end
