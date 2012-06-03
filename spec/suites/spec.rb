# -*- coding: utf-8; -*-

require "./spec/helpers/helper.rb"
require "./app/sinatra"
require "rack/test"
require "nokogiri"

use Rack::SSL
get "/spec/request_token" do
  request_token("/")
end

before do
  logger = Logger.new(STDOUT)
  logger.level = Logger::DEBUG
  env["rack.logger"] = logger

end

get "/spec/access_token" do
  # puts "gogog"
  # puts insert.to_sql

  "hogehuga"
end

RSpec.configure do
  include Helpers
  include Rack::Test::Methods
  def app
    Helpers::RunLoop.new(Sinatra::Application)
  end

  def sync &block
    EM.run do
      fb = Fiber.new do
        block.call
      end
      fb.resume

      ender = proc do |fb|
        EM.next_tick do
          if fb.alive?
            ender.call fb
          else
            EM.stop
          end
        end
      end
      ender.call fb
    end
  end

  def fetch(uri_str, limit = 10)
    # You should choose better exception.
    raise ArgumentError, 'HTTP redirect too deep' if limit == 0

    response = Net::HTTP.get_response(URI.parse(uri_str))
    case response
    when Net::HTTPSuccess
      response
    when Net::HTTPRedirection
      fetch(response['location'], limit - 1)
    else
      response.value
    end
  end

end


describe "helpers" do
  Result = Hashie::Mash.new

  it "request_token" do

    url = URI::Generic.
      build(
      scheme: config.admin_protocol,
      host:   config.admin_host,
      port:   config.admin_port,
      path:   "/").to_s

    get(url)

    Result.auth_url = last_response.body
    Result.cookie   = last_response.headers["Set-Cookie"]
  end

  it "request_token" do

    html = `curl -L "#{Result.auth_url}"`

    File.open "tmp/req.html", "w" do |fp|
      fp.puts html
    end

    pending

    doc = Nokogiri::HTML(html)

    form = doc.css("#login_form")

    action = form.attr("action")
    targetUrl = form.css("input[name='targetUrl']")[0].attr("value")


    uri = URI.parse(Result.auth_url)

    com = <<COM
curl -L \
-d "username=subak-en-test" \
-d "password=passpass" \
-d "login=Sign in" \
-d "targetUrl=#{targetUrl}" \
"#{config.evernote_site}#{action}"
COM

    puts com

    html = `#{com}`

    File.open "tmp/res.html", "w" do |fp|
      fp.puts html
    end


#    puts Net::HTTP.get(URI.parse Result.auth_url)
#    req = Net::HTTPRequest::Get Result.auth_url

    # pending
    # get("https://example.com/spec/request_token")
    # url = last_response.body
    # url.should match %r(^https://)
  end
end

# describe 'get("/")は' do
#   it "helloを返す" do
#     pending

#     get("https://example.com/")

#     p last_response.body
#     p last_response.headers
#     p last_response.successful?
#   end
# end


