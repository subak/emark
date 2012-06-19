# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20120619174745) do

  create_table "blog", :force => true do |t|
    t.text    "bid",      :default => "", :null => false
    t.integer "uid",      :default => 0,  :null => false
    t.text    "notebook"
    t.text    "title"
    t.text    "subtitle"
    t.text    "author"
  end

  add_index "blog", ["bid"], :name => "index_blog_on_blog_id", :unique => true

  create_table "blog_q", :force => true do |t|
    t.text    "bid"
    t.float   "queued"
    t.integer "lock",   :default => 0, :null => false
  end

  add_index "blog_q", ["bid"], :name => "index_blog_q_on_bid", :unique => true

  create_table "entry_q", :force => true do |t|
    t.text    "note_guid"
    t.integer "updated"
    t.text    "bid"
    t.float   "queued"
    t.integer "lock",      :default => 0, :null => false
  end

  add_index "entry_q", ["note_guid"], :name => "index_entry_on_note_guid", :unique => true

  create_table "meta_q", :force => true do |t|
    t.text    "bid"
    t.float   "queued"
    t.integer "lock",   :default => 0, :null => false
  end

  add_index "meta_q", ["bid"], :name => "index_meta_on_bid", :unique => true

  create_table "session", :force => true do |t|
    t.integer "uid",       :default => 0, :null => false
    t.text    "shard"
    t.text    "authtoken"
    t.integer "expires"
    t.text    "sid"
  end

  add_index "session", ["uid"], :name => "index_session_on_user_id", :unique => true

  create_table "sync", :force => true do |t|
    t.text    "note_guid"
    t.text    "title"
    t.integer "created"
    t.integer "updated"
    t.integer "deleted",   :default => 0, :null => false
    t.text    "bid"
    t.text    "eid"
  end

  add_index "sync", ["note_guid"], :name => "index_sync_on_note_guid", :unique => true

end
