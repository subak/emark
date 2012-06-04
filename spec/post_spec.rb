# -*- coding: utf-8; -*-

require "./app/sinatra"
config.environment  = :spec
config.logger_level = Logger::INFO
require "./spec/spec_helper.rb"

RSpec.configure do
  include Helpers
  include Rack::Test::Methods
end

describe "put /config" do
  before:all do
    delete_blog
  end

  it "sid無し" do
    put "/config/test.example.com"
    last_response.forbidden?.should be_true
  end

  it "不正なsid" do
    put("/config/test.example.com", {}, {
           "HTTP_COOKIE" => "sid=joifei83j3"
         })
    last_response.forbidden?.should be_true
  end

  describe "sid有り" do
    before:all do
      get_session
      @http_cookie = "sid=#{@session[:sid]}"
    end

    it "不正なblog_id" do
      put("/config/test.example.com", {}, {
             "HTTP_COOKIE" => @http_cookie
           })
      last_response.forbidden?.should be_true
    end

    describe "200" do
      before:all do
        insert = db.blog.insert_manager
        insert.insert([
                        [db.blog[:user_id], @session[:user_id]],
                        [db.blog[:blog_id], "test.example.com"]
                      ])
        db.execute insert.to_sql
      end

      it "パラメータ無し" do
        put("/config/test.example.com", {}, {
              "HTTP_COOKIE" => @http_cookie
            })
        last_response.ok?.should be_true
      end

      it "パラメータ有り" do
        put("/config/test.example.com", {
              "title" => "hogehuga"
            }, {
              "HTTP_COOKIE" => @http_cookie
            })
        last_response.ok?.should be_true
      end
    end
  end

  after:all do
    delete_blog
  end
end
