# -*- coding: utf-8; -*-

require "./app/workers/entry"
require "./spec/publish/spec_helper"

RSpec.configure do
  include Helper
  include Emark::Publish::Entry::Helper
end

describe Emark::Publish::Entry do
  before:all do
    get_session
    @entry_q = Emark::Publish::Entry.new
    @bid     = "test.example.com"
    @note = nil
  end

  describe "step_1" do
    before:all do
      delete_entry_q
    end

    it Emark::Publish::Empty do
      proc do
        @entry_q.step_1
      end.should raise_error(Emark::Publish::Empty)
    end

    describe "queue 有り" do
      before do
        insert = db.entry_q.insert_manager
        insert.insert([
                        [db.entry_q[:note_guid], "hogehuga"],
                        [db.entry_q[:updated],   Time.now.to_f],
                        [db.entry_q[:bid],       "test.example.com"],
                        [db.entry_q[:queued],    Time.now.to_f]
                      ])
        db.execute insert.to_sql
      end

      it "should return entry" do
        @entry = @entry_q.step_1
        @entry.should have_key(:note_guid)
        @entry.should have_key(:updated)
        @entry.should have_key(:bid)
        @entry.should have_key(:queued)
      end

    end
  end

  describe "step_2" do

    ##
    # 削除すべき
    # syncにだけ存在していて、evernoteには情報がない
    it Emark::Publish::Entry::Delete do
      proc do
        @entry_q.entry = {:updated => nil}
        @entry_q.step_2
      end.should raise_error(Emark::Publish::Entry::Delete)
    end

    ##
    # 他のブログに移っていた場合など、内容に変更は無いので
    # syncとevernoteのupdatedは同時刻の場合がある
    it Emark::Publish::Entry::Recover do
      note_guid = "12345"
      updated   = Time.now.to_f
      @entry_q.entry = {
        :note_guid => note_guid,
        :updated   => updated
      }

      delete_sync
      insert = db.sync.insert_manager
      insert.insert([
                      [db.sync[:note_guid], note_guid],
                      [db.sync[:updated],   updated]
                    ])
      db.execute insert.to_sql

      proc do
        @entry_q.step_2
      end.should raise_error Emark::Publish::Entry::Recover
    end

    it "ok" do
      bid       = "test.example.com"
      note_guid = "12345"
      updated   = Time.now.to_f
      @entry_q.entry = {
        :bid       => bid,
        :note_guid => note_guid,
        :updated   => updated + 10
      }

      delete_sync
      insert = db.sync.insert_manager
      insert.insert([
                      [db.sync[:bid],       bid],
                      [db.sync[:note_guid], note_guid],
                      [db.sync[:updated],   updated]
                    ])
      db.execute insert.to_sql

      @entry_q.step_2.should == bid
    end
  end

  ##
  # sessionの取得
  describe "step_3" do
    it Emark::Publish::Fatal do
      @entry_q.entry[:bid] = nil

      proc do
        @entry_q.step_3
      end.should raise_error Emark::Publish::Fatal
    end

    it "session取得" do
      bid = "test.example.com"
      delete_blog
      insert = db.blog.insert_manager
      insert.insert([
                      [db.blog[:uid], @session[:uid]],
                      [db.blog[:bid], bid]
                    ])
      db.execute insert.to_sql


      @entry_q.entry[:bid] = bid
      session = @entry_q.step_3
      session[:authtoken].should == @session[:authtoken]
    end
  end

  describe "step_4" do
    it Exception do
      begin
        @entry_q.step_4 "dummy_guid", @session[:authtoken], @session[:shard], @session[:notebook]
      rescue Exception => e
        e
      end.should be_a_kind_of(Exception)
    end

    it "ok" do
      noteStoreTransport = Thrift::HTTPClientTransport.new("#{config.evernote_site}/edam/note/#{@session[:shard]}")
      noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
      noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)

      filter = Evernote::EDAM::NoteStore::NoteFilter.new
      notes = noteStore.findNotes @session[:authtoken], filter, 0, 1
      guid = notes.notes[0].guid

      note = @entry_q.step_4 guid, @session[:authtoken], @session[:shard], @session[:notebook]

      note.guid.should == guid
      Vars[:note] = note
    end
  end

  ##
  # fixtureを用意したほうがよさそう
  describe "step_5" do
    it "markdownテキストを出力" do
      note = Vars[:note]
      @entry_q.step_5(note, @session[:shard]).should_not be_nil
    end
  end


  describe "write down" do
    before:all do
      @note_guid  = Digest::SHA1.new.update("hoge").to_s
      @eid        = Subak::Utility.shorten_hash(@note_guid).slice(0,4)
      @markdown   = "## hoge"
      @title      = "hoge"
      @created    = Time.now.to_i * 1000
      @updated    = Time.now.to_i * 1000
    end

    ##
    # markdownの書き出し
    it "step_6" do
      result = @entry_q.step_6 @note_guid, @markdown
      result.should match(/## hoge/)
    end

    ##
    # jsonを作成
    it "step_7" do
      result = @entry_q.step_7 @note_guid, @eid, @markdown, @title, @created, @updated
      logger.debug result
      json = JSON.parse result

      json["title"].should   == @title
      json["created"].should == Time.at(@created/1000).utc.iso8601
    end


    it "step_8" do
      result = @entry_q.step_8 @note_guid, @markdown, @title
      logger.debug result

      result.should match(/<h2>hoge/)
    end

    describe "step_9" do
      it "symlink無し" do
        dir  = File.join config.public_blog, @bid.slice(0,2), @bid, @eid
        json = dir + ".json"
        html = dir + ".html"
        File.unlink json if File.symlink?(json)
        File.unlink html if File.symlink?(html)

        @entry_q.step_9(@note_guid, @eid, @bid).should be_true
      end

      it "symlink有り" do
        @entry_q.step_9(@note_guid, @eid, @bid).should be_true
      end
    end


    describe "step_10" do
      before:all do
        delete_sync
      end

      ["insert", "update"].each do |action|
        it action do
          @entry_q.step_10(@note_guid, @eid, @bid, @title, @created, @updated).should be_true
        end
      end
    end
  end
end
