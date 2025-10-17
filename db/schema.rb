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

ActiveRecord::Schema[8.0].define(version: 2025_10_10_035603) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "event_on_archive_actions", ["keep", "hide", "move"]
  create_enum "event_states", ["presales", "reservee_purchases", "public_purchases", "archived"]
  create_enum "order_states", ["new", "success", "payment_failed", "cancelled", "refunded"]

  create_table "articles", force: :cascade do |t|
    t.text "title"
    t.text "slug", null: false
    t.text "article_hero_image", null: false
    t.text "summary"
    t.text "body"
    t.boolean "raw_editor", default: false, null: false
    t.bigint "page_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["page_id"], name: "index_articles_on_page_id"
    t.index ["slug"], name: "index_articles_on_slug", unique: true
  end

  create_table "events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "slug", null: false
    t.text "event_hero_image", null: false
    t.boolean "raw_editor", default: false, null: false
    t.bigint "page_id"
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.integer "number_of_seats", null: false
    t.integer "price_per_seat", null: false
    t.text "location"
    t.string "currency", limit: 3, null: false
    t.enum "state", default: "presales", null: false, enum_type: "event_states"
    t.enum "on_archive_action", default: "keep", null: false, enum_type: "event_on_archive_actions"
    t.jsonb "on_archive_params", default: {}, null: false
    t.index ["page_id"], name: "index_events_on_page_id"
    t.index ["slug"], name: "index_events_on_slug", unique: true
    t.index ["state"], name: "index_events_on_state"
  end

  create_table "orders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "event_id", null: false
    t.text "name", null: false
    t.text "email_address", null: false
    t.text "phone_number"
    t.text "notes"
    t.integer "number_of_seats", null: false
    t.integer "amount_owed", null: false
    t.enum "state", default: "new", null: false, enum_type: "order_states"
    t.index ["event_id"], name: "index_orders_on_event_id"
    t.index ["state"], name: "index_orders_on_state"
  end

  create_table "page_impressions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "path", null: false
    t.text "referrer"
    t.text "controller", null: false
    t.text "action", null: false
    t.jsonb "params", null: false
    t.integer "status", null: false
    t.index ["path"], name: "index_page_impressions_on_path"
  end

  create_table "pages", id: :serial, force: :cascade do |t|
    t.text "title", default: ""
    t.text "body", default: ""
    t.integer "page_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "position"
    t.boolean "hidden", default: false, null: false
    t.boolean "raw_editor", default: false, null: false
    t.string "page_type", default: "normal", null: false
    t.text "form_selection_list_contents", default: "", null: false
    t.text "slug", default: "", null: false
    t.text "navigation_title"
    t.text "form_selection_list_label"
    t.boolean "hide_date_and_time", default: false, null: false
    t.boolean "poster_grid", default: false, null: false
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
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "custom_file_name"
    t.index ["assetable_type", "assetable_id"], name: "idx_redactor_assetable"
    t.index ["assetable_type", "type", "assetable_id"], name: "idx_redactor_assetable_type"
  end

  create_table "revisions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "revisable_type", null: false
    t.bigint "revisable_id", null: false
    t.text "title"
    t.text "navigation_title"
    t.text "summary"
    t.text "body"
    t.boolean "published", default: false
    t.boolean "current", default: false
    t.index ["current"], name: "index_revisions_on_current"
    t.index ["published"], name: "index_revisions_on_published"
    t.index ["revisable_type", "revisable_id"], name: "index_revisions_on_revisable"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end
end
