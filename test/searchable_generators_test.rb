# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_search/searchable_pg_trgm/searchable_pg_trgm_generator"
require "generators/recording_studio_search/searchable_pgvector/searchable_pgvector_generator"

class SearchableGeneratorsTest < Minitest::Test
  def with_temp_app
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "db/migrate"))
      yield dir
    end
  end

  def test_trigram_generator_builds_generated_column_from_against
    with_temp_app do |dir|
      generator = RecordingStudioSearch::Generators::SearchablePgTrgmGenerator.new(
        ["User"],
        { against: "name,email" },
        destination_root: dir
      )
      generator.stub(:say, nil) { generator.add_trigram_migration }

      path = Dir.glob(File.join(dir, "db/migrate/*add_search_vector_to_users.rb")).first
      refute_nil path
      sql = File.read(path)

      assert_includes sql, 'enable_extension "pg_trgm"'
      assert_includes sql, ":search_vector, :tsvector"
      assert_includes sql, 'as: "to_tsvector'
      assert_includes sql, "coalesce(name::text, '') || ' ' || coalesce(email::text, '')"
      assert_includes sql, "opclass: :gin_trgm_ops"
      refute_includes sql, ":embedding"
      refute_includes sql, "setweight"
    end
  end

  def test_trigram_generator_builds_setweight_from_against_weights
    with_temp_app do |dir|
      generator = RecordingStudioSearch::Generators::SearchablePgTrgmGenerator.new(
        ["Page"],
        { against: "title:A,body:D" },
        destination_root: dir
      )
      generator.stub(:say, nil) { generator.add_trigram_migration }

      path = Dir.glob(File.join(dir, "db/migrate/*add_search_vector_to_pages.rb")).first
      sql = File.read(path)

      assert_includes sql, "setweight(to_tsvector('english', coalesce(title::text, '')), 'A')"
      assert_includes sql, "setweight(to_tsvector('english', coalesce(body::text, '')), 'D')"
      refute_includes sql, "|| ' ' ||"
    end
  end

  def test_pgvector_generator_does_not_add_model_embedding_columns
    with_temp_app do |dir|
      generator = RecordingStudioSearch::Generators::SearchablePgvectorGenerator.new(
        ["SupportPage"],
        { against: "title,body" },
        destination_root: dir
      )
      generator.stub(:say, nil) do
        generator.ensure_trigram
        generator.ensure_documents_migration
      end

      trigram = File.read(Dir.glob(File.join(dir, "db/migrate/*add_search_vector_to_support_pages.rb")).first)
      documents = File.read(Dir.glob(File.join(dir, "db/migrate/*create_recording_studio_search_documents.rb")).first)

      refute_includes trigram, "add_column :support_pages, :embedding"
      refute_includes documents, "add_column :support_pages"
      assert_includes documents, 'enable_extension "vector"'
      assert_includes documents, ":recording_studio_search_documents"
      assert_includes documents, "vector("
      assert_includes documents, ":searchable_type"
      assert_includes documents, ":recording_id"
    end
  end

  def test_second_pgvector_model_reuses_documents_migration
    with_temp_app do |dir|
      first = RecordingStudioSearch::Generators::SearchablePgvectorGenerator.new(
        ["SupportPage"],
        { against: "title,body" },
        destination_root: dir
      )
      first.stub(:say, nil) do
        first.ensure_trigram
        first.ensure_documents_migration
      end

      second = RecordingStudioSearch::Generators::SearchablePgvectorGenerator.new(
        ["Article"],
        { against: "title" },
        destination_root: dir
      )
      second.stub(:say, nil) do
        second.ensure_trigram
        second.ensure_documents_migration
      end

      documents = Dir.glob(File.join(dir, "db/migrate/*create_recording_studio_search_documents.rb"))
      articles = Dir.glob(File.join(dir, "db/migrate/*add_search_vector_to_articles.rb"))
      pages = Dir.glob(File.join(dir, "db/migrate/*add_search_vector_to_support_pages.rb"))

      assert_equal 1, documents.size
      assert_equal 1, articles.size
      assert_equal 1, pages.size
    end
  end
end
