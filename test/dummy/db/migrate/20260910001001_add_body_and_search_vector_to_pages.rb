# frozen_string_literal: true

class AddBodyAndSearchVectorToPages < ActiveRecord::Migration[8.1]
  def up
    add_column :pages, :body, :text unless column_exists?(:pages, :body)

    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    unless column_exists?(:pages, :search_vector)
      add_column :pages, :search_vector, :tsvector,
                 as: "to_tsvector('english', coalesce(title::text, '') || ' ' || coalesce(body::text, ''))",
                 stored: true
    end

    unless index_name_exists?(:pages, "index_pages_on_search_vector")
      add_index :pages, :search_vector, using: :gin, name: "index_pages_on_search_vector"
    end
    unless index_name_exists?(:pages, "index_pages_on_title_trgm")
      add_index :pages, :title, opclass: :gin_trgm_ops, using: :gin, name: "index_pages_on_title_trgm"
    end
    unless index_name_exists?(:pages, "index_pages_on_body_trgm")
      add_index :pages, :body, opclass: :gin_trgm_ops, using: :gin, name: "index_pages_on_body_trgm"
    end
  end

  def down
    remove_index :pages, name: "index_pages_on_body_trgm" if index_name_exists?(:pages, "index_pages_on_body_trgm")
    remove_index :pages, name: "index_pages_on_title_trgm" if index_name_exists?(:pages, "index_pages_on_title_trgm")
    remove_index :pages, name: "index_pages_on_search_vector" if index_name_exists?(:pages, "index_pages_on_search_vector")
    remove_column :pages, :search_vector if column_exists?(:pages, :search_vector)
    remove_column :pages, :body if column_exists?(:pages, :body)
  end
end
