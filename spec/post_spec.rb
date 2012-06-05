# -*- coding: utf-8; -*-

require "./app/sinatra"
config.environment  = :spec
config.logger_level = Logger::INFO
require "./spec/spec_helper.rb"

RSpec.configure do
  include Helpers
  include Rack::Test::Methods

  def sync &block
    EM.run do
      fb =Fiber.new do
        block.call
      end
      fb.resume
      EM.add_periodic_timer do
        EM.stop if fb.alive?.!
      end
    end
  end
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

describe "delete blog" do
  before:all do
    delete_blog
  end

  it "sid無し" do
    delete "/close/test.example.com"
    last_response.forbidden?.should be_true
  end

  it "不正なsid" do
    delete("/close/test.example.com", {}, {
           "HTTP_COOKIE" => "sid=joifei83j3"
         })
    last_response.forbidden?.should be_true
  end

  describe "sid有り" do
    before:all do
      get_session
      @http_cookie = "sid=#{@session[:sid]}"
    end

    it "不正なbid" do
      invalid_bid = "hoge.example.com"
      delete("/close/#{invalid_bid}", {}, {
            "HTTP_COOKIE" => @http_cookie
          })
      last_response.forbidden?.should be_true
    end

    describe "200" do
      before do
        @bid = "test.example.com"
        insert = db.blog.insert_manager
        insert.insert([
                        [db.blog[:user_id], @session[:user_id]],
                        [db.blog[:blog_id], @bid]
                      ])
        db.execute insert.to_sql
      end

      it "エイリアス削除" do
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

      it "publish.syncに削除済みフラグを付ける" do
        pending "db待ち"
      end
    end
  end

  after:all do
    delete_blog
  end
end

describe "logout" do
  it "200" do
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
