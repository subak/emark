# -*- coding: utf-8; -*-

require "simplecov"
SimpleCov.start do
  add_filter "vendor/bundle/"
  add_filter "lib/Evernote/"
end

require "./app/sinatra"
config.logger_level = Logger::INFO

require "./spec/http/spec_helper.rb"


describe "request_token" do

RSpec.configure do
  include Helpers
  include Rack::Test::Methods
end

  before:all do
    sync do
      url = URI::Generic.
        build(
        scheme: config.admin_protocol,
        host:   config.admin_host,
        port:   config.admin_port,
        path:   "/").to_s

      get(url)
    end
  end

  it "bodyにcallbackurlを返す" do
    last_response.body.include?(config.evernote_site).should be_true
  end

  it "rack.sessionがrequest_tokenを持つこと" do
    session = Rack::Session::Cookie::Base64::Marshal.new.decode rack_mock_session.cookie_jar["rack.session"]
    session[:request_token].should.respond_to?(:authorize_url)
  end
end

describe "access_token" do
  context "fail" do
    before do
      sync do
        url = URI::Generic.
          build(
          scheme: config.admin_protocol,
          host:   config.admin_host,
          port:   config.admin_port,
          path:   "/").to_s

        clear_cookies
        get(url)
        @request_url = last_response.body
      end
    end

    it "sessionの情報を持たない時は403" do
      sync do
        clear_cookies
        get(access_url(@request_url))

        last_response.forbidden?.should be_true
      end
    end
  end

  describe "success" do
    before:all do
      sync do
        delete = DeleteManager.new Table.engine
        delete.from db.session
        db.execute delete.to_sql
      end
    end

    2.times do |time|
      label = (0 == time) ? "insert" : "update"
      context label do
        before:all do
          sync do
            @url = URI::Generic.
              build(
              scheme: config.admin_protocol,
              host:   config.admin_host,
              port:   config.admin_port,
              path:   "/").to_s

            clear_cookies
            get(@url)
            request_url = last_response.body

            get(access_url(request_url))
          end
        end

        it "response.bodyは/を返す" do
pp last_response
          last_response.body.should == "/"
        end

        it "cookieはsidを含む" do
          rack_mock_session.cookie_jar["sid"].should be_true
        end

        # トラフィックの節約
        it "request_tokenが消されていること" do
          session = Rack::Session::Cookie::Base64::Marshal.new.decode rack_mock_session.cookie_jar["rack.session"]
          session[:request_token].should be_false
        end

        it "dashboardへリダイレクトされること" do
          sync do
            get(@url)
            last_response.body.should == "/dashboard"
          end
        end
      end
    end
  end
end

