# -*- coding: utf-8; -*-

require "simplecov"
SimpleCov.start do
  add_filter "vendor/bundle/"
  add_filter "lib/Evernote/"
end

require "./spec/publish/spec_helper"
require "./app/workers/publish/blog"

RSpec.configure do
  include Helper
end

describe Emark::Publish::Blog do
  RSpec.configure do
    include Emark::Publish::BlogHelper
  end

  before:all do
    @bid = "test.example.com"
    get_session
  end

  describe "Blog.dequeue" do
    before do
      delete_blog_q
    end

    def enqueue lock
      insert = db.blog_q.insert_manager
      insert.insert([
                      [db.blog_q[:bid],    @bid],
                      [db.blog_q[:queued], Time.now.to_f],
                      [db.blog_q[:lock],   lock]
                    ])
      db.execute insert.to_sql
    end

    it "empty" do
      dequeue.should be_nil
    end

    it "lock無し" do
      enqueue 0
      dequeue.should == @bid
    end

    it "lock有り" do
      enqueue 1
      dequeue.should be_nil
    end
  end

  describe "evernoteapiにアクセス" do
    before:all do
      guid = notebook_guid @session[:authtoken], @session[:shard]
      @notes = find_notes @session[:authtoken], @session[:shard], guid
    end

    describe "Blog.find_notes" do
      it "should return notes" do
        @notes.should be_a_kind_of(Evernote::EDAM::NoteStore::NotesMetadataList)
      end
    end

    describe "Blog.detect" do
      before:all do
        @notebooks = {}
        @notes.notes.each do |note|
          @notebooks[note.guid] = note.updated
        end
      end

      before do
        delete = DeleteManager.new Table.engine
        delete.from db.sync
        db.execute delete.to_sql
      end

      it "全てのノートはインサートされる" do
        detect(@notes, @bid).each do |key, value|
          value.should_not be_nil
        end
      end

      it "全てのノートはアップデートされる" do
        @notebooks.each do |guid, updated|
          insert = db.sync.insert_manager
          insert.insert([
                          [db.sync[:note_guid], guid],
                          [db.sync[:updated],   updated - 10],
                          [db.sync[:bid],       @bid]
                        ])
          db.execute insert.to_sql
        end

        detect(@notes, @bid).each do |guid, updated|
          updated.should_not be_nil
        end
      end

      it "何もしない" do
        @notebooks.each do |guid, updated|
          insert = db.sync.insert_manager
          insert.insert([
                          [db.sync[:note_guid], guid],
                          [db.sync[:updated],   updated],
                          [db.sync[:bid],       @bid]
                        ])
          db.execute insert.to_sql
        end

        detect(@notes, @bid).should be_empty
      end

      it "すべてのノートは削除される" do
        @notebooks.each do |guid, updated|
          insert = db.sync.insert_manager
          insert.insert([
                          [db.sync[:note_guid], guid],
                          [db.sync[:updated],   updated],
                          [db.sync[:bid],       @bid]
                        ])
          db.execute insert.to_sql
        end

        notes = @notes.dup
        notes.notes = []

        sync_notes = detect(notes, @bid)
        sync_notes.should_not be_empty

        sync_notes.each do |guid, updated|
          updated.should be_nil
        end
      end
    end
  end

  describe "Blog.enqueue_entry" do
    before:all do
      delete_entry_q
    end

    it "空" do
      enqueue_entry(@bid, {}).should == 0
    end

    it "ok" do
      enqueue_entry(@bid, {
                     "guid1" => Time.now.to_f,
                   }).should == 1

      select = db.entry_q.project(db.entry_q[:note_guid])
      select.where(db.entry_q[:bid].eq @bid)
      db.get_first_value(select.to_sql).should == "guid1"
    end

    it "重複" do
      enqueue_entry(@bid, {
                     "guid1" => Time.now.to_f,
                   }).should == 0
    end
  end

  describe "Blog.enqueue_meta" do
    before:all do
      delete_meta_q
    end

    it "空" do
      enqueue_meta(@bid, {}).should be_false
    end

    it "ok" do
      enqueue_meta(@bid, {
                     "guid1" => Time.now.to_f,
                   }).should be_true

      select = db.meta_q.project(db.meta_q[:bid])
      select.where(db.meta_q[:bid].eq @bid)
      db.get_first_value(select.to_sql).should == @bid
    end

    it "重複" do
      enqueue_meta(@bid, {
                     "guid1" => Time.now.to_f,
                   }).should be_false
    end
  end

  describe "Blog.delete_queue" do
    before do
      delete_blog_q
    end

    it "empty" do
      proc do
        delete_queue @bid
      end.should raise_error(Emark::Publish::Fatal)
    end

    it "lock" do
      insert = db.blog_q.insert_manager
      insert.insert([
                      [db.blog_q[:bid],  @bid],
                      [db.blog_q[:lock], 0]
                    ])
      db.execute insert.to_sql

      proc do
        delete_queue @bid
      end.should raise_error(Emark::Publish::Fatal)
    end
  end

  describe "Blog.run" do
    before do
      delete_blog
      delete_blog_q
      delete_entry_q
      delete_meta_q
      get_session
      @blog = Emark::Publish::Blog.new
    end

    describe "キュー無し" do
      it "Blog.run:empty" do
        sync do
          @blog.run.should be_false
        end
      end
    end

    describe "キュー有り" do
      before do
        insert = db.blog_q.insert_manager
        insert.insert([
                        [db.blog_q[:bid],    @bid],
                        [db.blog_q[:queued], Time.now.to_f]
                      ])
        db.execute insert.to_sql
      end

      it "ブログ無し" do
        proc do
          sync do
            @blog.run
          end
        end.should raise_error(Emark::Publish::Fatal)
      end

      it "ブログ有り" do
        insert = db.blog.insert_manager
        insert.insert([
                        [db.blog[:uid], @session[:uid]],
                        [db.blog[:bid], @bid]
                      ])
        db.execute insert.to_sql

        sync do
          @blog.run.should be_true
        end
      end
    end
  end
end
