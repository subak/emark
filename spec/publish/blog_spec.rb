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
                        [db.blog[:user_id], @session[:user_id]],
                        [db.blog[:blog_id], @bid]
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
    pending "これから"
  end
end
