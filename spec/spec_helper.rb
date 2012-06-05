# -*- coding: utf-8; -*-

require "pp"
require "fiber"
require "eventmachine"
require "logger"
require "digest/md5"
require "nokogiri"
require "rack/test"

ActiveRecord::Base.clear_all_connections!
ActiveRecord::Base.configurations = YAML.load(File.read "./db/config.yml")
ActiveRecord::Base.establish_connection config.environment
Table.engine = ActiveRecord::Base

configure do
  set :db, ActiveRecord::Base.connection.raw_connection
  settings.db.busy_handler do
    fb = Fiber.current
    EM.add_timer do
      fb.resume true
    end
    Fiber.yield
  end
end

helpers do
  def db.session
    settings.db_session
  end

  def db.blog
    settings.db_blog
  end

  def db.blog_q
    settings.db_blog_q
  end

  def db
    settings.db
  end
end

##
# 待ち時間無し
def sleep wait
  fb = Fiber.current
  logger.debug "sleep wait:#{wait}"
  EM.add_timer do
    fb.resume
  end
  Fiber.yield
end

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
      fb = Fiber.current
      env["async.callback"] = proc do |result|
        @result = result
        EM.add_timer do
          fb.resume @result
        end
      end
      catch :async do
        @app.call(env)
      end
      Fiber.yield
    end
  end

  def app
    Helpers::RunLoop.new(Sinatra::Application)
  end

  def db
    ActiveRecord::Base.connection.raw_connection
  end

  db = db

  def db.session
    Table.new(:session)
  end

  def db.blog
    Table.new(:blog)
  end

  def db.blog_q
    Table.new(:blog_q)
  end

  def admin_url path
    URI::Generic.
      build(
      scheme: config.admin_protocol,
      host:   config.admin_host,
      port:   config.admin_port,
      path:   path).to_s
  end

  def md5
    Digest::MD5.new.update(Time.now.to_f.to_s).to_s
  end

  def get_session
    select = db.session.project(SqlLiteral.new "*")
    select.where(db.session[:user_id].eq 25512727)
    @session = db.get_first_row select.to_sql
    raise "session error" if @session.!
    @http_cookie = "sid=#{@session[:sid]}"
  end

  def delete_blog
    delete = DeleteManager.new Table.engine
    delete.from db.blog
    db.execute delete.to_sql
  end

  def sync &block
    EM.run do
      fb = Fiber.new do
        block.call
      end
      fb.resume

      EM.add_periodic_timer do
        EM.stop if fb.alive?.!
      end
    end
  end

  SpecLogger = ::Logger.new(STDOUT)
  SpecLogger.level = config.logger_level
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
