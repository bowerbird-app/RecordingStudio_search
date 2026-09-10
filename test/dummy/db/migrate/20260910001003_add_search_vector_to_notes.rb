# frozen_string_literal: true

class AddSearchVectorToNotes < ActiveRecord::Migration[8.1]
  def up
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    unless column_exists?(:notes, :search_vector)
      add_column :notes, :search_vector, :tsvector,
                 as: "to_tsvector('english', coalesce(title::text, ''))",
                 stored: true
    end

    unless index_name_exists?(:notes, "index_notes_on_search_vector")
      add_index :notes, :search_vector, using: :gin, name: "index_notes_on_search_vector"
    end
    unless index_name_exists?(:notes, "index_notes_on_title_trgm")
      add_index :notes, :title, opclass: :gin_trgm_ops, using: :gin, name: "index_notes_on_title_trgm"
    end
  end

  def down
    remove_index :notes, name: "index_notes_on_title_trgm" if index_name_exists?(:notes, "index_notes_on_title_trgm")
    remove_index :notes, name: "index_notes_on_search_vector" if index_name_exists?(:notes, "index_notes_on_search_vector")
    remove_column :notes, :search_vector if column_exists?(:notes, :search_vector)
  end
end
