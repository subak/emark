# -*- coding: utf-8; -*-

require "./app/workers/blog"
require "./spec/publish/spec_helper"

RSpec.configure do
  include Helper
end

describe Emark::Publish::Blog do
  before:all do
    @blog = Emark::Publish::Blog.new db, logger
    @result = {}
  end

  describe "step_1" do
    before:all do
      sync do
        delete_blog
        delete_blog_q
      end
    end

    it Emark::Publish::Empty do
      sync do
        proc do
          @blog.step_1
        end.should raise_error(Emark::Publish::Empty)
      end
    end

    describe "キューがある時" do
      before do
        sync do
          @bid = "test.example.com"
          insert = db.blog_q.insert_manager
          insert.insert([
                          [db.blog_q[:bid],    @bid],
                          [db.blog_q[:queued], Time.now.to_f]
                        ])
          db.execute insert.to_sql
        end
      end

      it "should return bid" do
        sync do
          @blog.step_1.should == @bid
        end
      end

      it "should return oldest bid" do
        sync do
          insert = db.blog_q.insert_manager
          insert.insert([
                          [db.blog_q[:bid],    "hoge.example.com"],
                          [db.blog_q[:queued], Time.now.to_f]
                        ])
          db.execute insert.to_sql
          @blog.step_1.should == @bid
        end
      end
    end
  end

  describe "step_2" do
    before:all do
      sync do
        get_session

        @bid = "test.example.com"
        insert = db.blog.insert_manager
        insert.insert([
                        [db.blog[:uid], @session[:uid]],
                        [db.blog[:bid], @bid]
                      ])
        db.execute insert.to_sql
      end
    end

    it "ブログ無し" do
      sync do
        proc do
          @blog.step_2("hoge.example.com")
        end.should raise_error(Emark::Publish::Fatal)
      end
    end

    it "ブログ有り" do
      sync do
        @blog.step_2(@bid)[:authtoken].should == @session[:authtoken]
      end
    end
  end

  describe "step_3" do
    before:all do
      sync do
        get_session

        noteStoreTransport = Thrift::HTTPClientTransport.new("#{config.evernote_site}/edam/note/#{@session[:shard]}")
        noteStoreProtocol =  Thrift::BinaryProtocol.new(noteStoreTransport)
        noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)
        notebooks = noteStore.listNotebooks(@session[:authtoken])

        @guid = notebooks.first.guid
      end
    end

    it "不正なauthtoken" do
      sync do
        @blog.step_3("authtoken", @session[:shard], @guid).kind_of?(Evernote::EDAM::NoteStore::NotesMetadataList).should be_true
      end
      pending "不可解な結果"
    end

    it "不正なnotebook" do
      sync do
        proc do
          @blog.step_3 @session[:authtoken], @shard, "notebook"
        end.should raise_error
      end
    end

    it "ノートがない" do
      pending "テストできない"
      # ノートブックを増やすか
    end

    it "ok" do
      sync do
        result = @blog.step_3("authtoken", @session[:shard], @guid)
        result.kind_of?(Evernote::EDAM::NoteStore::NotesMetadataList).should be_true
        @result[:step_3] = result
      end
    end
  end

  describe "step_4" do
    before:all do
      @notebooks = {}
      @result[:step_3].notes.each do |note|
        @notebooks[note.guid] = note.updated
      end
    end

    before do
      delete = DeleteManager.new Table.engine
      delete.from db.sync
      db.execute delete.to_sql
    end

    it "sync無し insert" do
      @blog.step_4(@result[:step_3]).each do |key, value|
        value.should_not == 0
      end
    end

    describe "sync有り" do
      it "update" do
        @notebooks.each do |guid, updated|
          insert = db.sync.insert_manager
          insert.insert([
                          [db.sync[:note_guid], guid],
                          [db.sync[:updated],   updated - 10],
                          [db.sync[:bid],       @bid]
                        ])
          db.execute insert.to_sql
        end

        @blog.step_4(@result[:step_3]).each do |guid, updated|
          updated.should_not == 0
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

        @blog.step_4(@result[:step_3]).should be_empty
      end

      it "削除する" do
        insert = db.sync.insert_manager
        insert.insert([
                        [db.sync[:note_guid], "should_be_deleted"],
                        [db.sync[:updated],   Time.now.to_i],
                        [db.sync[:bid],       @bid]
                      ])
        db.execute insert.to_sql

        result = @blog.step_4(@result[:step_3])
        result.should have_key("should_be_deleted")
        result["should_be_deleted"].should be_nil
      end
    end
  end

  describe "step_5" do
    before:all do
      delete_entry_q
      @blog.bid = "test.example.com"
    end

    it "空" do
      @blog.step_5({}).should == 0
    end

    it "ok" do
      @blog.step_5({
                     "guid1" => Time.now.to_f,
                   }).should == 1

      select = db.entry_q.project(db.entry_q[:note_guid])
      select.where(db.entry_q[:bid].eq @blog.bid)
      db.get_first_value(select.to_sql).should == "guid1"
    end

    it "重複" do
      @blog.step_5({
                     "guid1" => Time.now.to_f,
                   }).should == 0
    end
  end

  describe "step_6" do
    before:all do
      delete_meta_q
      @blog.bid = "test.example.com"
    end

    it "空" do
      @blog.step_6({}).should be_false
    end

    it "ok" do
      @blog.step_6({
                     "guid1" => Time.now.to_f,
                   }).should be_true

      select = db.meta_q.project(db.meta_q[:bid])
      select.where(db.meta_q[:bid].eq @blog.bid)
      db.get_first_value(select.to_sql).should == @blog.bid
    end

    it "重複" do
      @blog.step_6({
                     "guid1" => Time.now.to_f,
                   }).should be_false
    end
  end

  describe "run" do
    before do
      delete_blog
      delete_blog_q
      delete_entry_q
      delete_meta_q
      get_session

          # @bid = "test.example.com"
          # insert = db.blog_q.insert_manager
          # insert.insert([
          #                 [db.blog_q[:bid],    @bid],
          #                 [db.blog_q[:queued], Time.now.to_f]
          #               ])
          # db.execute insert.to_sql
    end

    it "キュー無し" do
      proc do
        @blog.run
      end.should raise_error(Emark::Publish::Empty)
    end

    describe "キュー有り" do
      before do
        @bid = "test.example.com"
        insert = db.blog_q.insert_manager
        insert.insert([
                        [db.blog_q[:bid],    @bid],
                        [db.blog_q[:queued], Time.now.to_f]
                      ])
        db.execute insert.to_sql
      end

      it "ブログ無し" do
        proc do
          @blog.run
        end.should raise_error(Emark::Publish::Fatal)
      end

      describe "ブログ有り" do
        before do
          @bid = "test.example.com"
          insert = db.blog.insert_manager
          insert.insert([
                          [db.blog[:uid], @session[:uid]],
                          [db.blog[:bid], @bid]
                        ])
          db.execute insert.to_sql
        end

        it "hoge" do
          sync do
            @blog.run.should >= 1
          end
        end
      end
    end
  end
end
