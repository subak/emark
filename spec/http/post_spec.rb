# -*- coding: utf-8; -*-

require "./app/sinatra"
config.environment  = :spec
config.logger_level = Logger::INFO
require "./spec/http/spec_helper.rb"

RSpec.configure do
  include Helpers
  include Rack::Test::Methods
end

describe "put /config" do
  before:all do
    sync do
      delete_blog
    end
  end

  it "sid無し" do
    sync do
      put "/config/test.example.com"
      last_response.forbidden?.should be_true
    end
  end

  it "不正なsid" do
    sync do
      put("/config/test.example.com", {}, {
            "HTTP_COOKIE" => "sid=joifei83j3"
          })
      last_response.forbidden?.should be_true
    end
  end

  describe "sid有り" do
    before:all do
      sync do
        get_session
      end
    end

    it "不正なblog_id" do
      sync do
        put("/config/test.example.com", {}, {
              "HTTP_COOKIE" => @http_cookie
            })
        last_response.forbidden?.should be_true
      end
    end

    describe "200" do
      before:all do
        sync do
          insert = db.blog.insert_manager
          insert.insert([
                          [db.blog[:user_id], @session[:user_id]],
                          [db.blog[:blog_id], "test.example.com"]
                        ])
          db.execute insert.to_sql
        end
      end

      it "パラメータ無し" do
        sync do
          put("/config/test.example.com", {}, {
                "HTTP_COOKIE" => @http_cookie
              })
          last_response.ok?.should be_true
        end
      end

      it "パラメータ有り" do
        sync do
          put("/config/test.example.com", {
                "title" => "hogehuga"
              }, {
                "HTTP_COOKIE" => @http_cookie
              })
          last_response.ok?.should be_true
        end
      end
    end
  end
end

describe %!delete "/close/:bid"! do
  before:all do
    sync do
      delete_blog
    end
  end

  it "sid無し" do
    sync do
      delete "/close/test.example.com"
      last_response.forbidden?.should be_true
    end
  end

  it "不正なsid" do
    sync do
      delete("/close/test.example.com", {}, {
               "HTTP_COOKIE" => "sid=joifei83j3"
             })
      last_response.forbidden?.should be_true
    end
  end

  describe "sid有り" do
    before:all do
      sync do
        get_session
      end
    end

    it "不正なbid" do
      sync do
        invalid_bid = "hoge.example.com"
        delete("/close/#{invalid_bid}", {}, {
                 "HTTP_COOKIE" => @http_cookie
               })
        last_response.forbidden?.should be_true
      end
    end

    describe "200" do
      before do
        sync do
          @bid = "test.example.com"
          insert = db.blog.insert_manager
          insert.insert([
                          [db.blog[:user_id], @session[:user_id]],
                          [db.blog[:blog_id], @bid]
                        ])
          db.execute insert.to_sql
        end
      end

      it "エイリアス削除" do
        sync do
          path = File.join(config.public_blog, @bid.slice(0, 2), @bid, "test.html")
          FileUtils.mkdir_p File.dirname(path)
          FileUtils.touch path
          FileUtils.symlink path, "#{path}.link" if File.exist?("#{path}.link").!

          delete("/close/#{@bid}", {}, {
                   "HTTP_COOKIE" => @http_cookie
                 })
          last_response.ok?.should be_true
          File.exist?(path).should be_false
        end
      end

      it "publish.syncに削除済みフラグを付ける" do
        pending "db待ち"
      end
    end
  end
end

describe "logout" do
  it "200" do
    sync do
      get_session
      @http_cookie = "sid=#{@session[:sid]}"

      delete("/logout", {}, {
               "HTTP_COOKIE" => @http_cookie
             })

      select = db.session.project(db.session[:sid])
      select.where(db.session[:sid].eq @session[:sid])
      db.get_first_row(select.to_sql).should be_false

      last_response.body.should == config.site_href

      insert = db.session.insert_manager
      insert.insert([
                      [db.session[:user_id],   @session[:user_id]],
                      [db.session[:shard],     @session[:shard]],
                      [db.session[:authtoken], @session[:authtoken]],
                      [db.session[:expires],   @session[:expires]],
                      [db.session[:sid],       @session[:sid]]
                    ])
      db.execute insert.to_sql
    end
  end
end

describe %!put "/sync/:bid"! do
  before:all do
    sync do
      get_session
      @http_cookie = "sid=#{@session[:sid]}"

      delete_blog

      delete = DeleteManager.new Table.engine
      delete.from db.blog_q
      db.execute delete.to_sql

      @bid = "test.example.com"

      insert = db.blog.insert_manager
      insert.insert([
                      [db.blog[:user_id], @session[:user_id]],
                      [db.blog[:blog_id], @bid]
                    ])
      db.execute insert.to_sql
    end
  end

  it "sid無し" do
    sync do
      put "/sync/test.example.com"
      last_response.forbidden?.should be_true
    end
  end

  describe "sid有り" do
    it "不正なbid" do
      sync do
        put("/sync/hoge.example.com", {}, {
              "HTTP_COOKIE" => @http_cookie
            })
        last_response.forbidden?.should be_true
      end
    end

    it "200" do
      sync do
        put("/sync/#{@bid}", {}, {
              "HTTP_COOKIE" => @http_cookie
            })
        last_response.ok?.should be_true
        json = JSON.parse(last_response.body)
        json["queued"].should be_true
      end
    end

    it "重複" do
      sync do
        put("/sync/#{@bid}", {}, {
              "HTTP_COOKIE" => @http_cookie
            })
        last_response.ok?.should be_true
        json = JSON.parse(last_response.body)
        json["queued"].should be_false
      end
    end
  end
end
