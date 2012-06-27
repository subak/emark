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
        put("/blogs/test.example.com", {}.to_json, {
              "HTTP_COOKIE" => @http_cookie
            })
        last_response.forbidden?.should be_true
      end
    end

    describe "blog有り" do
      before:all do
        sync do
          insert = db.blog.insert_manager
          insert.insert([
                          [db.blog[:uid], @session[:uid]],
                          [db.blog[:bid], "test.example.com"]
                        ])
          db.execute insert.to_sql
        end
      end

      it "パラメータ無し" do
        sync do
          put("/blogs/test.example.com", {}.to_json, {
                "HTTP_COOKIE" => @http_cookie
              })
          last_response.forbidden?.should be_true
        end
      end

      it "パラメータ有り" do
        sync do
          put("/blogs/test.example.com", {
                "paginate"      => 3,
                "recent_posts"  => 4,
                "excerpt_count" => 12
              }.to_json, {
                "HTTP_COOKIE" => @http_cookie
              })
          last_response.ok?.should be_true
        end
      end
    end
  end
end

describe %!delete "/blogs/:bid"! do
  before:all do
    sync do
      delete_blog
    end
  end

  it "sid無し" do
    sync do
      delete "/blogs/test.example.com"
      last_response.forbidden?.should be_true
    end
  end

  it "不正なsid" do
    sync do
      delete("/blogs/test.example.com", {}, {
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
        delete("/blogs/#{invalid_bid}", {}, {
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
                          [db.blog[:uid], @session[:uid]],
                          [db.blog[:bid], @bid]
                        ])
          db.execute insert.to_sql
        end
      end

      it "エイリアス削除" do
        path = File.join(config.public_blog, @bid.slice(0, 2), @bid, "test.html")
        FileUtils.mkdir_p File.dirname(path)
        FileUtils.touch path
        FileUtils.symlink path, "#{path}.link" if File.exist?("#{path}.link").!

        sync do
          delete("/blogs/#{@bid}", {}, {
                   "HTTP_COOKIE" => @http_cookie
                 })
        end

        last_response.ok?.should be_true
        File.exist?(path).should be_false
      end

      it "publish.syncに削除済みフラグを付ける" do
        sync do
          delete_sync

          insert = db.sync.insert_manager
          insert.insert([
                          [db.sync[:note_guid], "same_bid"],
                          [db.sync[:bid],       @bid],
                        ])
          db.execute insert.to_sql

          insert = db.sync.insert_manager
          insert.insert([
                          [db.sync[:note_guid], "diff_bid"],
                          [db.sync[:bid],       "hoge.example.com"],
                        ])
          db.execute insert.to_sql


          delete("/blogs/#{@bid}", {}, {
                   "HTTP_COOKIE" => @http_cookie
                 })
          last_response.ok?.should be_true

          select = db.sync.project(db.sync[:deleted])
          select.where(db.sync[:note_guid].eq "same_bid")
          db.get_first_value(select.to_sql).should == 1

          select = db.sync.project(db.sync[:deleted])
          select.where(db.sync[:note_guid].eq "diff_bid")
          db.get_first_value(select.to_sql).should == 0

        end
      end
    end
  end
end

describe "logout" do
  it "200" do
    sync do
      get_session
      @http_cookie = "sid=#{@session[:sid]}"

      delete("/logout/#{@session[:sid]}", {}, {
               "HTTP_COOKIE" => @http_cookie
             })

      select = db.session.project(db.session[:sid])
      select.where(db.session[:sid].eq @session[:sid])
      db.get_first_row(select.to_sql).should be_false

      JSON.parse(last_response.body)["location"].should == config.site_href

      insert = db.session.insert_manager
      insert.insert([
                      [db.session[:uid],       @session[:uid]],
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
                      [db.blog[:uid], @session[:uid]],
                      [db.blog[:bid], @bid]
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
        get("/sync/hoge.example.com", {}, {
              "HTTP_COOKIE" => @http_cookie
            })
        last_response.forbidden?.should be_true
      end
    end

    it "200" do
      sync do
        get("/sync/#{@bid}", {}, {
              "HTTP_COOKIE" => @http_cookie
            })
        last_response.ok?.should be_true
        json = JSON.parse(last_response.body)
        json["queued"].should be_true
      end
    end

    it "重複" do
      sync do
        get("/sync/#{@bid}", {}, {
              "HTTP_COOKIE" => @http_cookie
            })
        last_response.ok?.should be_true
        json = JSON.parse(last_response.body)
        json["queued"].should be_false
      end
    end
  end
end
