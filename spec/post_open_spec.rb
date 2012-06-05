# -*- coding: utf-8; -*-

require "./app/sinatra"
config.environment  = :spec
config.logger_level = Logger::INFO
require "./spec/spec_helper.rb"

RSpec.configure do
  include Helpers
  include Rack::Test::Methods
end

describe "post /open" do
  before:all do
    sync do
      delete_blog
    end
  end

  it "sid無し" do
    sync do
      post "/open"
      last_response.forbidden?.should be_true
    end
  end

  it "不正なsid" do
    sync do
      post("/open", {}, {
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

    it "session無し" do
      sync do
        post("/open", {}, {
               "HTTP_COOKIE" => @http_cookie
             })
        last_response.forbidden?.should be_true
      end
    end

    describe "session有り" do
      before:all do
        sync do
          @blog_id = "test.example.com"

          ##
          # 共有状態にする
          noteStoreTransport = Thrift::HTTPClientTransport.new("#{config.evernote_site}/edam/note/#{@session[:shard]}")
          noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
          @noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)
          notebooks = @noteStore.listNotebooks(@session[:authtoken])
          notebooks.each do |notebook|
            begin
              publishing = Evernote::EDAM::Type::Publishing.
                new(:uri => @blog_id)
              newbook = Evernote::EDAM::Type::Notebook.
                new(
                :guid       => notebook.guid,
                :name       => notebook.name,
                :publishing => publishing,
                :published  => true)
              @noteStore.updateNotebook @session[:authtoken], newbook
            rescue Exception => e
              pp e
            end
          end

          @guid = notebooks.first.guid
          get("https://example.com/open", {}, {
                "HTTP_COOKIE"  => @http_cookie
              })

          cookies = rack_mock_session.cookie_jar.cookies
          cookies << @http_cookie
          @http_cookie = cookies.join("; ")
          clear_cookies
        end
      end

      it "パラメータなし" do
        sync do
          post("https://example.com/open", {}, {
                 "HTTP_COOKIE"  => @http_cookie,
               })
          last_response.forbidden?.should be_true
        end
      end

      it "notebookGuidがない" do
        pending "後で"
      end
      it "domainがない" do
        pending "後で"
      end
      it "subdomainがない" do
        pending "後で"
      end

      it "ノートブックが含まれていない" do
        sync do
          post("/open", {
                 "domain"       => "hoge",
                 "subdomain"    => "example.com",
                 "notebookGuid" => "dummydummydummy"
               }, {
                 "HTTP_COOKIE"  => @http_cookie
               })
          last_response.forbidden?.should be_true
        end
      end

      describe "ノートブックが含まれている" do
        it "ドメイン名が不正" do
          sync do
            post("/open", {
                   "domain"       => "--hoge@@",
                   "subdomain"    => "example.com",
                   "notebookGuid" => @guid
                 }, {
                   "HTTP_COOKIE"  => @http_cookie
                 })
            last_response.forbidden?.should be_true
          end
        end

        it "200" do
          sync do
            post("/open", {
                   "domain"       => "test",
                   "subdomain"    => "example.com",
                   "notebookGuid" => @guid
                 }, {
                   "HTTP_COOKIE" => @http_cookie
                 })
            last_response.ok?.should be_true
          end
        end

        it "すでに公開されているブログ" do
          sync do
            post("/open", {
                   "domain"       => "test",
                   "subdomain"    => "example.com",
                   "notebookGuid" => @guid
                 }, {
                   "HTTP_COOKIE" => @http_cookie
                 })
            last_response.forbidden?.should be_true
          end
        end
      end
    end
  end
end
