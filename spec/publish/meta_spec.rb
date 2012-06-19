# -*- coding: utf-8; -*-

require "./app/workers/meta"
require "./spec/publish/spec_helper"

RSpec.configure do
  include Helper
  include Emark::Publish::Meta
end


describe Emark::Publish::Meta do
  before:all do
    @bid    = "test.example.com"
    @title  = "my first blog"
    @subtitle = "this is my first blog"
    @author = "Jhon Doe"
    @entries = []
    @entries << {
      bid:     @bid,
      eid:     "s80x",
      title:   "first entry",
      created: Time.now.utc.iso8601,
      updated: Time.now.utc.iso8601
    }
    @entries << {
      bid:     @bid,
      eid:     "b99e",
      title:   "second entry",
      created: Time.now.utc.iso8601,
      updated: Time.now.utc.iso8601
    }
    @blog = {
      bid:      @bid,
      title:    @title,
      subtitle: @subtitle,
      author:   @author,
    }

  end

  describe "queue" do
    before:all do
      delete_meta_q
      delete_entry_q
    end

    describe "キュー無し" do
      it :empty do
        dequeue()[:empty].should be_true
      end
    end

    describe "キュー有り" do
      before:all do
        @queued = Time.now.to_f - 10; logger.debug @queued
        insert  = db.meta_q.insert_manager
        insert.insert([
                        [db.meta_q[:bid],    @bid],
                        [db.meta_q[:queued], @queued]
                      ])
        db.execute insert.to_sql

        insert = db.entry_q.insert_manager
        insert.insert([
                        [db.entry_q[:note_guid], "012345"],
                        [db.entry_q[:queued],    Time.now.to_f],
                        [db.entry_q[:bid],       @bid]
                      ])
        db.execute insert.to_sql
      end

      it :left do
        dequeue()[:left].should be_true

        select = db.meta_q.project(db.meta_q[:queued])
        select.where(db.meta_q[:bid].eq @bid)
        db.get_first_value(select.to_sql).should > @queued
      end

      it "lockされていないqueueは削除できない" do
        proc do
          delete_queue(@bid)
        end.should raise_error(Emark::Publish::Fatal)
      end

      it "ok" do
        delete_entry_q
        dequeue()[:bid].should == @bid

        select = db.meta_q.project(db.meta_q[:lock])
        select.where(db.meta_q[:bid].eq @bid)
        db.get_first_value(select.to_sql).should == 1
      end

      it Emark::Publish::Fatal do
        proc do
          dequeue
        end.should raise_error(Emark::Publish::Fatal)
      end

      it "delete_queue" do
        delete_queue(@bid).should be_true
      end
    end
  end

  describe "ファイル生成" do
    it "sitemap.xml" do
      xml = sitemap @entries
      logger.debug xml
      xml.should match %r{<loc>http://#{@bid}}
    end

    it "atom.xml" do
      xml = atom @entries, @blog
      logger.debug xml
    end

    it "index.html" do
      html = index_html @entries, @blog
      logger.debug html
    end
  end

  describe "run" do
    before:all do
      delete_meta_q
      delete_entry_q
      delete_blog
      delete_sync

      insert  = db.meta_q.insert_manager
      insert.insert([
                      [db.meta_q[:bid],    @bid],
                      [db.meta_q[:queued], Time.now.to_f]
                    ])
      db.execute insert.to_sql

      # insert = db.entry_q.insert_manager
      # insert.insert([
      #                 [db.entry_q[:note_guid], "012345"],
      #                 [db.entry_q[:queued],    Time.now.to_f],
      #                 [db.entry_q[:bid],       @bid]
      #               ])
      # db.execute insert.to_sql

      insert = db.blog.insert_manager
      insert.insert([
                      [db.blog[:bid],      @bid],
                      [db.blog[:title],    @title],
                      [db.blog[:subtitle], @subtitle],
                      [db.blog[:author],   @author]
                    ])
      db.execute insert.to_sql

      @entries.each do |entry|
        insert = db.sync.insert_manager
        insert.insert([
                        [db.sync[:bid],   entry[:bid]],
                        [db.sync[:eid],   entry[:eid]],
                        [db.sync[:title], entry[:title]],
                        [db.sync[:created], Time.now.to_f * 1000],
                        [db.sync[:updated], Time.now.to_f * 1000]
                      ])
        db.execute insert.to_sql
      end
    end

    it "throught" do
      sync do
        Emark::Publish::Meta.run
      end
    end
  end
end
