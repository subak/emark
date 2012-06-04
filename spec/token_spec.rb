# -*- coding: utf-8; -*-

require "./app/sinatra"
config.environment  = :spec
config.logger_level = Logger::INFO
require "./spec/spec_helper.rb"

# before do
#   logger = Logger.new(STDOUT)
#   logger.level = config.logger_level
#   env["rack.logger"] = logger
# end

# ActiveRecord::Base.clear_all_connections!
# ActiveRecord::Base.configurations = YAML.load(File.read "./db/config.yml")
# ActiveRecord::Base.establish_connection config.environment
# Table.engine = ActiveRecord::Base

# set :db, ActiveRecord::Base.connection.raw_connection
# set :db_session, Table.new(:session)

# helpers do
#   def db.session
#     settings.db_session
#   end

#   def db
#     settings.db
#   end
# end

RSpec.configure do
  include Helpers
  include Rack::Test::Methods
  # def app
  #   Helpers::RunLoop.new(Sinatra::Application)
  # end

  # def db
  #   ActiveRecord::Base.connection.raw_connection
  # end

  # def db.session
  #   Table.new(:session)
  # end

  # Result = Hashie::Mash.new
end

describe "request_token" do
  before:all do
    url = URI::Generic.
      build(
      scheme: config.admin_protocol,
      host:   config.admin_host,
      port:   config.admin_port,
      path:   "/").to_s

    get(url)
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

    it "sessionの情報を持たない時は403" do
      clear_cookies
      get(access_url(@request_url))

      last_response.forbidden?.should be_true
    end
  end

  describe "success" do
    before:all do
      delete = DeleteManager.new Table.engine
      delete.from db.session
      db.execute delete.to_sql
    end

    2.times do |time|
      label = (0 == time) ? "insert" : "update"
      context label do
        before:all do
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

        it "response.bodyは/を返す" do
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
          get(@url)
          last_response.body.should == "/dashboard"
        end
      end
    end
  end
end

