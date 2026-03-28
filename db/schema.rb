# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_28_194546) do
  create_table "repos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "disk_path", null: false
    t.text "embedding"
    t.datetime "last_pushed_at"
    t.string "name", null: false
    t.string "owner", null: false
    t.integer "stars_count", default: 0, null: false
    t.string "tags"
    t.datetime "updated_at", null: false
    t.index ["owner", "name"], name: "index_repos_on_owner_and_name", unique: true
  end

  create_table "stars", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "repo_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["repo_id"], name: "index_stars_on_repo_id"
    t.index ["user_id", "repo_id"], name: "index_stars_on_user_id_and_repo_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "pat_digest", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end
end
