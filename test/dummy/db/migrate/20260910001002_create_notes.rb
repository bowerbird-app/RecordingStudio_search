# frozen_string_literal: true

class CreateNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :notes, id: :uuid do |t|
      t.string :title
      t.timestamps
    end
  end
end
