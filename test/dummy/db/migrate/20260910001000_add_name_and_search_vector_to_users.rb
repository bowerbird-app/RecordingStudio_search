# frozen_string_literal: true

class AddNameAndSearchVectorToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :name, :string unless column_exists?(:users, :name)

    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    unless column_exists?(:users, :search_vector)
      add_column :users, :search_vector, :tsvector,
                 as: "to_tsvector('english', coalesce(name::text, '') || ' ' || coalesce(email::text, ''))",
                 stored: true
    end

    unless index_name_exists?(:users, "index_users_on_search_vector")
      add_index :users, :search_vector, using: :gin, name: "index_users_on_search_vector"
    end
    unless index_name_exists?(:users, "index_users_on_name_trgm")
      add_index :users, :name, opclass: :gin_trgm_ops, using: :gin, name: "index_users_on_name_trgm"
    end
    unless index_name_exists?(:users, "index_users_on_email_trgm")
      add_index :users, :email, opclass: :gin_trgm_ops, using: :gin, name: "index_users_on_email_trgm"
    end
  end

  def down
    remove_index :users, name: "index_users_on_email_trgm" if index_name_exists?(:users, "index_users_on_email_trgm")
    remove_index :users, name: "index_users_on_name_trgm" if index_name_exists?(:users, "index_users_on_name_trgm")
    remove_index :users, name: "index_users_on_search_vector" if index_name_exists?(:users, "index_users_on_search_vector")
    remove_column :users, :search_vector if column_exists?(:users, :search_vector)
    remove_column :users, :name if column_exists?(:users, :name)
  end
end
