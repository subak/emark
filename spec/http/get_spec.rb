# -*- coding: utf-8; -*-

require "./app/sinatra"
config.environment  = :spec
config.logger_level = Logger::INFO
require "./spec/http/spec_helper.rb"

RSpec.configure do
  include Helpers
  include Rack::Test::Methods
end

describe "dashboard" do
  before:all do
    sync do
      delete_blog
    end
  end

  describe "sid無し" do
    it "403" do
      sync do
        get(admin_url "/dashboard")
        last_response.forbidden?.should be_true
      end
    end
  end

  describe "sid有り" do
    before:all do
      sync do
        get_session
      end
    end

    it "公開ブログ無し" do
      sync do
        get(admin_url("/dashboard"), {}, {
              "HTTP_COOKIE" => "sid=#{@session[:sid]}"
            })
        JSON.parse(last_response.body)["blogs"].size.should == 0
      end
    end

    2.times do |time|
      n = time + 1
      it "公開ブログ#{n}個" do
        sync do
          insert = db.blog.insert_manager
          insert.insert([
                          [db.blog[:user_id], @session[:user_id]],
                          [db.blog[:blog_id], Digest::MD5.new.update(Time.now.to_f.to_s).to_s],
                          [db.blog[:notebook], Digest::MD5.new.update(Time.now.to_f.to_s).to_s]
                        ])
          db.execute insert.to_sql

          get(admin_url("/dashboard"), {}, {
                "HTTP_COOKIE" => "sid=#{@session[:sid]}"
              })
          JSON.parse(last_response.body)["blogs"].size.should == n
        end
      end
    end
  end
end

describe "config" do
  before:all do
    sync do
      delete_blog
      get_session
    end
  end

  it "sid無し" do
    sync do
      get admin_url("/config/test.example.com")
      last_response.forbidden?.should be_true
    end
  end

  it "不正なsid" do
    sync do
      get(admin_url("/config/test.example.com"), {}, {
            "HTTP_COOKIE" => "sid=3ru98fjier"
          })
      last_response.forbidden?.should be_true
    end
  end

  describe "sid有り" do
    before:all do
      sync do
        get_session

        @blog_id  = "test.example.com"
        @notebook = md5
        insert = db.blog.insert_manager
        insert.insert([
                        [db.blog[:user_id],  @session[:user_id]],
                        [db.blog[:blog_id],  @blog_id],
                        [db.blog[:notebook], @notebook]
                      ])
        db.execute insert.to_sql
      end
    end

    it "ブログが見つからない" do
      sync do
        get(admin_url("/config/hoge.example.com"), {}, {
              "HTTP_COOKIE" => "sid=#{@session[:sid]}"
            })
        last_response.forbidden?.should be_true
      end
    end

    it "ブログ取得" do
      sync do
        get(admin_url("/config/#{@blog_id}"), {}, {
              "HTTP_COOKIE" => "sid=#{@session[:sid]}"
            })
        json = JSON.parse(last_response.body)
        json["notebook"].should == @notebook
      end
    end
  end
end

describe "check" do
  before:all do
    sync do
      delete_blog
    end
  end

  it "sid無し" do
    sync do
      get admin_url("/check/blogid/test.example.com")
      last_response.forbidden?.should be_true
    end
  end

  it "不正なsid" do
    sync do
      get(admin_url("/check/blogid/test.example.com"), {}, {
            "HTTP_COOKIE" => "sid=3ru98fjier"
          })
      last_response.forbidden?.should be_true
    end
  end

  describe "sid有り" do
    before:all do
      sync do
        get_session

        @blog_id  = "test.example.com"
        @notebook = md5
        insert = db.blog.insert_manager
        insert.insert([
                        [db.blog[:user_id],  @session[:user_id]],
                        [db.blog[:blog_id],  @blog_id],
                        [db.blog[:notebook], @notebook]
                      ])
        db.execute insert.to_sql
      end
    end

    it "ブログが見つかった" do
      sync do
        get(admin_url("/check/blogid/#{@blog_id}"), {}, {
              "HTTP_COOKIE" => "sid=#{@session[:sid]}"
            })
        json = JSON.parse(last_response.body)
        json["available"].should be_false
      end
    end

    it "ブログが見つからない" do
      sync do
        get(admin_url("/check/blogid/hoge.exsample.com"), {}, {
              "HTTP_COOKIE" => "sid=#{@session[:sid]}"
            })
        json = JSON.parse(last_response.body)
        json["available"].should be_true
      end
    end
  end
end
