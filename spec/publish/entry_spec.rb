# -*- coding: utf-8; -*-

require "./app/workers/entry"
require "./spec/publish/spec_helper"

RSpec.configure do
  include Helper
end

describe Emark::Publish::Entry do
  before:all do
    get_session
    @entry_q = Emark::Publish::Entry.new
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

  ##
  # markdownの書き出し
  describe "step_6" do
  end

  ##
  # jsonを作成
  describe "step_7" do
  end

  ##
  # 検索エンジン用のhtmlを作成
  describe "step_8" do
  end

  ##
  # エイリアスを作成
  describe "step_9" do
  end
end

=begin
{"id"=>76,
 "uid"=>25512727,
 "shard"=>"s8",
 "authtoken"=>
  "S=s8:U=1854b17:E=13f098627ea:C=137b1d4fbf3:P=185:A=tk84-1998:H=95f41033cb6ca020aaeab0f3ab27555d",
 "expires"=>1370254354,
 "sid"=>"befa118f1edae2dbf9dc7c734a822387",
 0=>76,
 1=>25512727,
 2=>"s8",
 3=>
  "S=s8:U=1854b17:E=13f098627ea:C=137b1d4fbf3:P=185:A=tk84-1998:H=95f41033cb6ca020aaeab0f3ab27555d",
 4=>1370254354,
  5=>"befa118f1edae2dbf9dc7c734a822387"}
=end
