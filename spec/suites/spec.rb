# -*- coding: utf-8; -*-

require "./spec/helpers/helper.rb"
require "./app/sinatra"
require "rack/test"
require "nokogiri"

use Rack::SSL

config.environment  = :spec
config.logger_level = Logger::INFO

before do
  logger = Logger.new(STDOUT)
  logger.level = config.logger_level
  env["rack.logger"] = logger
end

ActiveRecord::Base.clear_all_connections!
ActiveRecord::Base.configurations = YAML.load(File.read "./db/config.yml")
ActiveRecord::Base.establish_connection config.environment
Table.engine = ActiveRecord::Base

set :db, ActiveRecord::Base.connection.raw_connection
set :db_session, Table.new(:session)

helpers do
  def db.session
    settings.db_session
  end

  def db
    settings.db
  end
end

RSpec.configure do
  include Helpers
  include Rack::Test::Methods
  def app
    Helpers::RunLoop.new(Sinatra::Application)
  end

  Result = Hashie::Mash.new
end

# describe "request_token" do
#   before do
#     url = URI::Generic.
#       build(
#       scheme: config.admin_protocol,
#       host:   config.admin_host,
#       port:   config.admin_port,
#       path:   "/").to_s

#     get(url)
#   end

#   it "bodyにcallbackurlを返す" do
#     url     = last_response.body
#     url.should be_true

#     Result.auth_url = url
#   end

#   it "cookieにrack.sessionを持つ" do
#     cookies = last_response.headers["Set-Cookie"]
#     cookies.should be_true

#     pp rack_mock_session.cookie_jar.cookies

#     Result.cookies = rack_mock_session.cookie_jar.cookies
#   end
# end

describe "access_token" do
  before:all do
    @url = URI::Generic.
      build(
      scheme: config.admin_protocol,
      host:   config.admin_host,
      port:   config.admin_port,
      path:   "/").to_s

    get(@url)
    request_url = last_response.body
    logger.info request_url
    cookies     = rack_mock_session.cookie_jar.cookies
    get(access_url(request_url), {}, {
          "HTTP_COOKIE" => cookies.join("; ")
        })
  end

  # it "rack.sessionがないアクセスで403になる" do
  #   get(@url, oauth_verifier: oauth_verifier(Result.auth_url))
  #   last_response.forbidden?.should be_true
  # end

  it "response.bodyは/を返す" do
    last_response.body.should == "/"
  end

  it "cookieはsidを含む" do
    rack_mock_session.cookie_jar["sid"].should be_true
  end

  it "hoge" do
    p rack_mock_session.cookie_jar["rack.session"]
  end
end

