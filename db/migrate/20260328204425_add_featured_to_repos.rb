class AddFeaturedToRepos < ActiveRecord::Migration[8.1]
  def change
    add_column :repos, :featured, :boolean, default: false, null: false
  end
end
