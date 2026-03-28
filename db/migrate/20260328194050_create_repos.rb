class CreateRepos < ActiveRecord::Migration[8.1]
  def change
    create_table :repos do |t|
      t.string :owner, null: false
      t.string :name, null: false
      t.text :description
      t.string :tags
      t.string :disk_path, null: false
      t.datetime :last_pushed_at
      t.text :embedding
      t.integer :stars_count, null: false, default: 0

      t.timestamps
    end

    add_index :repos, [ :owner, :name ], unique: true
  end
end
