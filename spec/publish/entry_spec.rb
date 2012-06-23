# -*- coding: utf-8; -*-

require "simplecov"
SimpleCov.start do
  add_filter "vendor/bundle/"
  add_filter "lib/Evernote/"
end

require "./app/workers/entry"
require "./spec/publish/spec_helper"

RSpec.configure do
  include Helper
end

describe Emark::Publish::Entry do
  RSpec.configure do
    include Emark::Publish::EntryHelper
  end

  before:all do
    get_session
    @bid     = "test.example.com"
    @note    = nil
  end

  describe "dequeue" do
    before:all do
      delete_entry_q
      @guid = "12345"
    end

    it Emark::Publish::Empty do
      dequeue.should be_false
    end

    describe "queue 有り" do
      before do
        insert = db.entry_q.insert_manager
        insert.insert([
                        [db.entry_q[:note_guid], @guid],
                        [db.entry_q[:updated],   Time.now.to_f],
                        [db.entry_q[:bid],       @bid],
                        [db.entry_q[:queued],    Time.now.to_f]
                      ])
        db.execute insert.to_sql
      end

      it "should return entry" do
        entry = dequeue
        entry.should have_key(:note_guid)
        entry.should have_key(:updated)
        entry.should have_key(:bid)
        entry.should have_key(:queued)
      end
    end
  end

  describe "detect" do
    before do
      delete_sync
    end

    ##
    # 削除すべき
    # syncにだけ存在していて、evernoteには情報がない
    it Emark::Publish::Entry::Delete do
      proc do
        detect nil, nil
      end.should raise_error(Emark::Publish::Entry::Delete)
    end

    ##
    # 他のブログに移っていた場合など、内容に変更は無いので
    # syncとevernoteのupdatedは同時刻の場合がある
    it Emark::Publish::Entry::Recover do
      updated = Time.now.to_f

      insert = db.sync.insert_manager
      insert.insert([
                      [db.sync[:bid],       @bid],
                      [db.sync[:note_guid], @guid],
                      [db.sync[:updated],   updated]
                    ])
      db.execute insert.to_sql

      proc do
        detect @guid, updated
      end.should raise_error Emark::Publish::Entry::Recover
    end

    it "ok" do
      updated   = Time.now.to_f

      insert = db.sync.insert_manager
      insert.insert([
                      [db.sync[:bid],       @bid],
                      [db.sync[:note_guid], @guid],
                      [db.sync[:updated],   updated]
                    ])
      db.execute insert.to_sql

      detect(@guid, updated+10).should be_true
    end
  end


  describe "evenote api にアクセス" do
    before:all do
      @guid = get_real_guid @session[:authtoken], @session[:shard]
      @note = note @guid, @session[:authtoken], @session[:shard]
    end

    describe "note" do
      it Exception do
        begin
          note "dummy_guid", @session[:authtoken], @session[:shard], @session[:notebook]
        rescue Exception => e
          e
        end.should be_a_kind_of(Exception)
      end

      it "ok" do
        @note.guid.should == @guid
      end
    end

    ##
    # fixtureを用意したほうがよさそう
    describe "markdown" do
      it "markdownテキストを出力" do
        markdown(@note, @session[:shard]).should_not be_nil
      end
    end
  end

  describe "write down" do
    before:all do
      @note_guid  = Digest::SHA1.new.update("hoge").to_s
      @eid        = Subak::Utility.shorten_hash(@note_guid).slice(0,4)
      @markdown   = File.read "./spec/publish/fixtures/markdown.md"
      @title      = File.read "./spec/publish/fixtures/title.txt"
      @created    = Time.now.to_i * 1000
      @updated    = Time.now.to_i * 1000
    end

    ##
    # jsonを作成
    it "entry_json" do
      result = entry_json @note_guid, @eid, @markdown, @title, @created, @updated
      logger.debug result
      json = JSON.parse result

      json["title"].should   == @title
      json["created"].should == Time.at(@created/1000).utc.iso8601
    end


    it "entry_html" do
      entry_html @note_guid, @markdown, @title
    end


    describe "update_sync" do
      before:all do
        delete_sync
      end

      ["insert", "update"].each do |action|
        it action do
          update_sync(@note_guid, @eid, @bid, @title, @created, @updated).should be_true
        end
      end
    end
  end

  describe "キューの削除" do
    before do
      @guid = "012345"
      delete_entry_q
    end

    it "lockが0の時失敗" do
      insert = db.entry_q.insert_manager
      insert.insert([
                      [db.entry_q[:note_guid], @guid],
                      [db.entry_q[:lock], 0]
                    ])
      db.execute insert.to_sql

      proc do
        delete_queue(@guid)
      end.should raise_error Emark::Publish::Fatal
    end

    it "success" do
      insert = db.entry_q.insert_manager
      insert.insert([
                      [db.entry_q[:note_guid], @guid],
                      [db.entry_q[:lock], 1]
                    ])
      db.execute insert.to_sql

      delete_queue(@guid).should be_true
    end
  end

  describe "run" do
    before:all do
      @entry = Emark::Publish::Entry.new
    end

    it "empty" do
      sync do
        @entry.run.should be_false
      end
    end

    describe "ok" do
      before:all do
        delete_entry_q
        delete_blog
        delete_sync
        get_session

        @bid  = "test.example.com"
        @guid = get_real_guid @session[:authtoken], @session[:shard]
        @eid  = Subak::Utility.shorten_hash(@guid.gsub("-", "")).slice(0, 4)

        insert = db.blog.insert_manager
        insert.insert([
                        [db.blog[:uid], @session[:uid]],
                        [db.blog[:bid], @bid]
                      ])
        db.execute insert.to_sql

        insert = db.entry_q.insert_manager
        insert.insert([
                        [db.entry_q[:note_guid], @guid],
                        [db.entry_q[:updated],   Time.now.to_i * 1000],
                        [db.entry_q[:bid],       @bid],
                        [db.entry_q[:queued],    Time.now.to_f]
                      ])
        db.execute insert.to_sql
      end

      it "through" do
        sync do
          @entry.run.should be_true
        end
      end

      it "delete" do
        insert = db.entry_q.insert_manager
        insert.insert([
                        [db.entry_q[:note_guid], @guid],
                        [db.entry_q[:updated],   nil],
                        [db.entry_q[:bid],       @bid],
                        [db.entry_q[:queued],    Time.now.to_f]
                      ])
        db.execute insert.to_sql

        sync do
          @entry.run.should == :delete
        end
      end

      it "recover" do
        delete_entry_q

        select = db.sync.project(db.sync[:updated])
        select.where(db.sync[:note_guid].eq @guid)
        update_sync = db.get_first_value select.to_sql

        insert = db.entry_q.insert_manager
        insert.insert([
                        [db.entry_q[:note_guid], @guid],
                        [db.entry_q[:updated],   update_sync],
                        [db.entry_q[:bid],       @bid],
                        [db.entry_q[:queued],    Time.now.to_f]
                      ])
        db.execute insert.to_sql

        sync do
          @entry.run.should == :recover
        end
      end
    end
  end
end
