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

ActiveRecord::Schema.define(:version => 20120604074259) do

  create_table "blog", :force => true do |t|
    t.text    "blog_id",  :default => "", :null => false
    t.integer "user_id",  :default => 0,  :null => false
    t.text    "notebook"
    t.text    "title"
    t.text    "subtitle"
    t.text    "author"
  end

  add_index "blog", ["blog_id"], :name => "index_blog_on_blog_id", :unique => true

  create_table "session", :force => true do |t|
    t.integer "user_id",       :default => 0, :null => false
    t.text    "notebook_id"
    t.text    "shard"
    t.text    "notestore_url"
    t.text    "authtoken"
    t.integer "expires"
    t.text    "sid"
  end

  add_index "session", ["user_id"], :name => "index_session_on_user_id", :unique => true

end
