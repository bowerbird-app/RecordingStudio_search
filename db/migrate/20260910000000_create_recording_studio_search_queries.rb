# frozen_string_literal: true

class CreateRecordingStudioSearchQueries < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_search_queries, id: :uuid do |t|
      t.string :keyword, null: false
      t.jsonb :embedding, null: false
      t.string :embedding_model, null: false
      t.datetime :embedding_at, null: false
      t.integer :hit_count, default: 0, null: false
      t.timestamps
    end

    add_index :recording_studio_search_queries,
              %i[keyword embedding_model],
              unique: true,
              name: "index_rss_queries_on_keyword_and_model"
  end
end
