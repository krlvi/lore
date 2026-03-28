class CreateStars < ActiveRecord::Migration[8.1]
  def change
    create_table :stars do |t|
      t.integer :user_id, null: false
      t.integer :repo_id, null: false

      t.timestamps
    end

    add_index :stars, [ :user_id, :repo_id ], unique: true
    add_index :stars, :repo_id
  end
end
