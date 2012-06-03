# -*- coding: utf-8; -*-

require "pp"
require "fiber"
require "eventmachine"
require "logger"

module Rack
  module Test
    class Cookie
      def name_value_raw
        @name_value_raw
      end
    end

    class CookieJar
      def cookies
        ary = []
        @cookies.each do |cookie|
          ary << cookie.name_value_raw
        end
        ary
      end
    end
  end
end

module Helpers
  class RunLoop
    def initialize app
      @app = app
    end

    def call(env)
      EM.run do
        env["async.callback"] = proc do |result|
          @result = result
          EM.stop
        end
        catch :async do
          @app.call(env) do
            p "hugahoge"
          end
        end
      end
      @result
    end
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

  SpecLogger = ::Logger.new(STDOUT)
  SpecLogger.level = ::Logger::INFO
  def logger
    SpecLogger
  end

  def access_url request_url
    com = <<COM
curl -L \
-c "tmp/step-1.cookies" \
"#{request_url}" \
> tmp/step-1.html
COM

    logger.info  com
    logger.debug `#{com}`

    doc    = Nokogiri::HTML(File.open "tmp/step-1.html")
    form   = doc.css("#login_form")
    action = form.attr("action")
    targetUrl = form.css("input[name='targetUrl']")[0].attr("value")

    com = <<COM
curl -L \
-d "username=subak-en-test" \
-d "password=passpass" \
-d "login=Sign in" \
-d "targetUrl=#{targetUrl}" \
-b "tmp/step-1.cookies" \
-c "tmp/step-2.cookies" \
"#{config.evernote_site}#{action}" \
> "tmp/step-2.html"
COM
    logger.info  com
    logger.debug `#{com}`

    doc    = Nokogiri::HTML(File.open "tmp/step-2.html")
    form   = doc.css("form[name='oauth_authorize_form']")
    action = form.attr("action")
    oauth_token = form.css("input[name='oauth_token']")[0].attr("value")

    com = <<COM
curl \
-d "authorize=true" \
-d "oauth_token=#{oauth_token}" \
-d "embed=false" \
-b "tmp/step-2.cookies" \
-c "tmp/step-3.cookies" \
-D "tmp/step-3.headers" \
"#{config.evernote_site}#{action}" \
> "tmp/step-3.html"
COM
    logger.info  com
    logger.debug `#{com}`

    raise "oauth fail" if not File.read("tmp/step-3.headers") =~ %r!^Location: (.*)$!
    location = Regexp.last_match[1]
    logger.info location

    location
  end
end
