# frozen_string_literal: true

class WeightPageSearchVector < ActiveRecord::Migration[8.1]
  def up
    if index_name_exists?(:pages, "index_pages_on_search_vector")
      remove_index :pages, name: "index_pages_on_search_vector"
    end
    remove_column :pages, :search_vector if column_exists?(:pages, :search_vector)

    add_column :pages, :search_vector, :tsvector,
               as: "setweight(to_tsvector('english', coalesce(title::text, '')), 'A') || setweight(to_tsvector('english', coalesce(body::text, '')), 'D')",
               stored: true
    add_index :pages, :search_vector, using: :gin, name: "index_pages_on_search_vector"
  end

  def down
    if index_name_exists?(:pages, "index_pages_on_search_vector")
      remove_index :pages, name: "index_pages_on_search_vector"
    end
    remove_column :pages, :search_vector if column_exists?(:pages, :search_vector)

    add_column :pages, :search_vector, :tsvector,
               as: "to_tsvector('english', coalesce(title::text, '') || ' ' || coalesce(body::text, ''))",
               stored: true
    add_index :pages, :search_vector, using: :gin, name: "index_pages_on_search_vector"
  end
end
