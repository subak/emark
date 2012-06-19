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

  ##
  # step_1
  describe "step_1" do
    before:all do
      delete_meta_q
      delete_entry_q
    end

    describe "キュー無し" do
      it :empty do
        Emark::Publish::Meta.run

#        catch(:dequeue) { self.class.dequeue }

        # proc do
        #   @meta_q.step_1
        # end.should raise_error(Emark::Publish::Meta::Empty)
      end
    end

    # describe "キュー有り" do
    #   before:all do
    #     @queued = Time.now.to_f - 10; logger.debug @queued
    #     insert  = db.meta_q.insert_manager
    #     insert.insert([
    #                     [db.meta_q[:bid],    @bid],
    #                     [db.meta_q[:queued], @queued]
    #                   ])
    #     db.execute insert.to_sql

    #     insert = db.entry_q.insert_manager
    #     insert.insert([
    #                     [db.entry_q[:note_guid], "012345"],
    #                     [db.entry_q[:queued],    Time.now.to_f],
    #                     [db.entry_q[:bid],       @bid]
    #                   ])
    #     db.execute insert.to_sql
    #   end

    #   it Emark::Publish::Meta::Left do
    #     proc do
    #       @meta_q.step_1
    #     end.should raise_error(Emark::Publish::Meta::Left)

    #     select = db.meta_q.project(db.meta_q[:queued])
    #     select.where(db.meta_q[:bid].eq @bid)

    #     db.get_first_value(select.to_sql).should > @queued
    #   end

    #   it "ok" do
    #     delete_entry_q
    #     @meta_q.step_1.should == @bid
    #   end
  end
end


__END__

  describe "step_4" do
    it "run" do
      xml = @meta_q.step_4 @entries
      logger.debug xml
      xml.should match %r{<loc>http://#{@bid}}
    end
  end

  describe "step_5" do
    it "run" do
      xml = @meta_q.step_5 @entries, @blog
      logger.debug xml
    end
  end

  describe "step_8" do
    it "run" do
      html = @meta_q.step_8 @entries, @blog
      logger.debug html
    end
  end

end
