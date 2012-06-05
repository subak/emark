# -*- coding: utf-8; -*-

require "./app/workers/blog"
require "./spec/publish/spec_helper"

RSpec.configure do
  include Helper
end

describe Emark::Publish::Blog do
  before:all do
    @blog = Emark::Publish::Blog.new db, logger
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
        puts insert.to_sql
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
end
