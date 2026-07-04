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

ActiveRecord::Schema[8.1].define(version: 2026_07_04_155708) do
  create_table "comments", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "file_path"
    t.integer "line_number"
    t.integer "parent_id"
    t.integer "pull_request_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["pull_request_id"], name: "index_comments_on_pull_request_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "pull_requests", force: :cascade do |t|
    t.string "author", null: false
    t.string "base_branch", null: false
    t.string "base_sha", null: false
    t.datetime "created_at", null: false
    t.string "head_branch", null: false
    t.string "head_sha", null: false
    t.string "mergeable_state"
    t.integer "number", null: false
    t.integer "repo_config_id", null: false
    t.string "state", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["repo_config_id", "number"], name: "index_pull_requests_on_repo_config_id_and_number", unique: true
    t.index ["repo_config_id"], name: "index_pull_requests_on_repo_config_id"
  end

  create_table "repo_configs", force: :cascade do |t|
    t.string "access_token"
    t.datetime "created_at", null: false
    t.string "last_sync_error"
    t.datetime "last_sync_failed_at"
    t.string "name"
    t.string "owner"
    t.datetime "updated_at", null: false
  end

  create_table "review_states", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "last_viewed_sha"
    t.integer "pull_request_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["pull_request_id"], name: "index_review_states_on_pull_request_id"
    t.index ["user_id", "pull_request_id"], name: "index_review_states_on_user_id_and_pull_request_id", unique: true
    t.index ["user_id"], name: "index_review_states_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "stack_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "manual_override"
    t.integer "position"
    t.integer "pull_request_id", null: false
    t.integer "stack_id", null: false
    t.datetime "updated_at", null: false
    t.index ["pull_request_id"], name: "index_stack_memberships_on_pull_request_id", unique: true
    t.index ["stack_id"], name: "index_stack_memberships_on_stack_id"
  end

  create_table "stacks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "repo_config_id", null: false
    t.datetime "updated_at", null: false
    t.index ["repo_config_id"], name: "index_stacks_on_repo_config_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "comments", "comments", column: "parent_id"
  add_foreign_key "comments", "pull_requests"
  add_foreign_key "comments", "users"
  add_foreign_key "pull_requests", "repo_configs"
  add_foreign_key "review_states", "pull_requests"
  add_foreign_key "review_states", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "stack_memberships", "pull_requests"
  add_foreign_key "stack_memberships", "stacks"
  add_foreign_key "stacks", "repo_configs"
end
