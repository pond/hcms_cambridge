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

ActiveRecord::Schema.define(version: 2020_05_03_234816) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "articles", force: :cascade do |t|
    t.text "title", null: false
    t.text "slug", null: false
    t.text "article_hero_image", null: false
    t.text "summary", null: false
    t.text "body", null: false
    t.boolean "raw_editor", default: false, null: false
    t.bigint "page_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["page_id"], name: "index_articles_on_page_id"
    t.index ["slug"], name: "index_articles_on_slug", unique: true
  end

  create_table "carrier_wave_files", id: :serial, force: :cascade do |t|
    t.string "identifier"
    t.string "original_filename"
    t.string "content_type"
    t.string "size"
    t.binary "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "pages", id: :serial, force: :cascade do |t|
    t.text "title", default: "", null: false
    t.text "body", default: "", null: false
    t.integer "page_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "position"
    t.boolean "hidden", default: false, null: false
    t.boolean "raw_editor", default: false, null: false
    t.string "page_type", default: "normal", null: false
    t.text "form_selection_list_contents", default: "", null: false
    t.text "slug", default: "", null: false
    t.index ["slug"], name: "index_pages_on_slug", unique: true
  end

  create_table "redactor_assets", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "data_file_name", null: false
    t.string "data_content_type"
    t.integer "data_file_size"
    t.integer "assetable_id"
    t.string "assetable_type", limit: 30
    t.string "type", limit: 30
    t.integer "width"
    t.integer "height"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["assetable_type", "assetable_id"], name: "idx_redactor_assetable"
    t.index ["assetable_type", "type", "assetable_id"], name: "idx_redactor_assetable_type"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

end
