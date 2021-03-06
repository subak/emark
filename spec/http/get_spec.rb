# -*- coding: utf-8; -*-

require "simplecov"
SimpleCov.start do
  add_filter "vendor/bundle/"
  add_filter "lib/Evernote/"
end

require "./app/sinatra"
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
        get(admin_url "/blogs")
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
        get(admin_url("/blogs"), {}, {
              "HTTP_COOKIE" => "sid=#{@session[:sid]}"
            })
        JSON.parse(last_response.body).size.should == 0
      end
    end

    2.times do |time|
      n = time + 1
      it "公開ブログ#{n}個" do
        sync do
          insert = db.blog.insert_manager
          insert.insert([
                          [db.blog[:uid], @session[:uid]],
                          [db.blog[:bid], Digest::MD5.new.update(Time.now.to_f.to_s).to_s],
                          [db.blog[:notebook], Digest::MD5.new.update(Time.now.to_f.to_s).to_s]
                        ])
          db.execute insert.to_sql

          get(admin_url("/blogs"), {}, {
                "HTTP_COOKIE" => "sid=#{@session[:sid]}"
              })
          JSON.parse(last_response.body).size.should == n
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
                        [db.blog[:uid],  @session[:uid]],
                        [db.blog[:bid],  @blog_id],
                        [db.blog[:notebook], @notebook]
                      ])
        db.execute insert.to_sql
      end
    end

    xit "ブログが見つからない" do
      sync do
        get(admin_url("/config/hoge.example.com"), {}, {
              "HTTP_COOKIE" => "sid=#{@session[:sid]}"
            })
        last_response.forbidden?.should be_true
      end
    end

    xit "ブログ取得" do
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
      get admin_url("/check/test.example.com")
      last_response.forbidden?.should be_true
    end
  end

  it "不正なsid" do
    sync do
      get(admin_url("/check/test.example.com"), {}, {
            "HTTP_COOKIE" => "sid=3ru98fjier"
          })
      last_response.forbidden?.should be_true
    end
  end

  describe "sid有り" do
    before:all do
      sync do
        get_session

        @bid      = "test.example.com"
        @notebook = md5
        insert = db.blog.insert_manager
        insert.insert([
                        [db.blog[:uid],      @session[:uid]],
                        [db.blog[:bid],      @bid],
                        [db.blog[:notebook], @notebook]
                      ])
        db.execute insert.to_sql
      end
    end

    it "ブログが見つかった" do
      sync do
        get(admin_url("/check/bid"), {bid: @bid}, {
              "HTTP_COOKIE" => "sid=#{@session[:sid]}"
            })
        last_response.body.should == "false"
      end
    end

    it "ブログが見つからない" do
      sync do
        get(admin_url("/check/bid"), {bid: "hoge.example.com"}, {
              "HTTP_COOKIE" => "sid=#{@session[:sid]}"
            })
        last_response.body.should == "true"
      end
    end
  end
end
