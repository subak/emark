# -*- coding: utf-8 -*-

require "pp"
require "digest/md5"
require "json"
Bundler.require :default
require "./lib/override/sqlite3"

require "./config/environment"
include Emark
$: << "./lib/Evernote/EDAM"
require 'note_store'
require 'limits_constants'
require "user_store"
require "user_store_constants.rb"
require "errors_types.rb"

Thread.abort_on_exception = config.thread_abort
EM.threadpool_size = 100
use Rack::FiberPool , :size => 200
use Rack::Session::Cookie, {
  :http_only => true,
  :secure => true}

ActiveRecord::Base.configurations = YAML.load(File.read "./db/config.yml")
ActiveRecord::Base.establish_connection config.environment
include Arel
Table.engine = ActiveRecord::Base

##
# sinatra
configure do
  disable :show_exceptions
  set :environment, config.environment
  set :db, ActiveRecord::Base.connection.raw_connection
  set :db_session, Table.new(:session)
  set :db_blog,    Table.new(:blog)
end

helpers do
  def db.session
    settings.db_session
  end

  def db.blog
    settings.db_blog
  end

  def db
    settings.db
  end
end

error do
  logger.fatal env['sinatra.error']
  500
end

class Forbidden < Exception; end
error Forbidden do
  e = env['sinatra.error']
  logger.warn "#{e}: #{e.backtrace().first}"
  403
end

before do
  logger.level = config.logger_level

  @session = {}
  sid = request.cookies["sid"]

  if sid
    select = db.session.project(SqlLiteral.new "*")
    select.where(db.session[:sid].eq sid)
    select.where(db.session[:expires].gt Time.now.to_i)
    query select.to_sql do |sql|
      @session = db.get_first_row sql
    end

    if @session.!
      response.delete_cookie:sid
      halt(403)
    end
  elsif request.request_method != "GET"
    halt 403
  elsif request.path != "/"
    halt 403
  end
end

after do
  headers 'Content-Type' => 'application/json; charset=utf-8'
end

##
# routing
#
get "/" do
  if oauthVerifier = request.params['oauth_verifier']
    ##
    # access_token

    requestToken = env["rack.session"][:request_token]
    raise Forbidden, "request_token" if requestToken.!

    accessToken = thread do
      requestToken.get_access_token :oauth_verifier => oauthVerifier
    end

    user = thread do
      userStoreTransport = Thrift::HTTPClientTransport.new("#{config.evernote_site}/edam/user")
      userStoreProtocol = Thrift::BinaryProtocol.new(userStoreTransport)
      userStore = Evernote::EDAM::UserStore::UserStore::Client.new(userStoreProtocol)
      user = userStore.getUser(accessToken.params[:oauth_token])
    end

    select = db.session.project db.session[:user_id]
    select.where(db.session[:user_id].eq user.id)
    res = query select.to_sql do |sql|
      db.get_first_value sql
    end

    sid     = Digest::MD5.new.update(Time.now.to_f.to_s).to_s
    expires = (accessToken.params[:edam_expires].to_i/1000).to_i
    manager =
      if res
        update = UpdateManager.new Table.engine
        update.table db.session
        update.set([
                     [db.session[:authtoken], accessToken.params[:oauth_token]],
                     [db.session[:expires],   expires],
                     [db.session[:sid],       sid]
                   ])
        update
      else
        insert = InsertManager.new Table.engine
        insert.into db.session
        insert.insert([
                        [db.session[:user_id],   user.id],
                        [db.session[:shard],     user.shardId],
                        [db.session[:authtoken], accessToken.params[:oauth_token]],
                        [db.session[:expires],   expires],
                        [db.session[:sid],       sid]
                      ])
        insert
      end

    query manager.to_sql do |sql|
      db.execute sql
    end

    env["rack.session"][:request_token] = nil
    response.set_cookie:sid, value: sid, expires: Time.at(expires)

    body "/"

  elsif @session[:authtoken]
    body '/dashboard'

  else
    ##
    # request token

    redirectPath = "/"
    callbackUrl = URI::Generic.build(
                               scheme: config.admin_protocol,
                               host:   config.admin_host,
                               port:   config.admin_port,
                               path:   redirectPath)
    consumer = OAuth::Consumer.
      new(
      config.evernote_oauth_consumer_key,
      config.evernote_oauth_consumer_secret,
      site:               config.evernote_site,
      request_token_path: "/oauth",
      access_token_path:  "/oauth",
      authorize_path:     "/OAuth.action")

    requestToken = thread do
      consumer.get_request_token(:oauth_callback => callbackUrl)
    end

    env["rack.session"][:request_token] = requestToken
    body requestToken.authorize_url
  end
end

get "/dashboard" do
  sleep 1

  blogs = []
  select = db.blog.project(SqlLiteral.new "*")
  select.where(db.blog[:user_id].eq @session[:user_id])
  query select.to_sql do |sql|
    db.execute sql do |row|
      blogs << row
    end
  end

  body({blogs: blogs}.to_json)
end

get "/open" do
  sleep 1

  notebooks = thread do
    noteStoreTransport = Thrift::HTTPClientTransport.new("#{config.evernote_site}/edam/note/#{@session[:shard]}")
    noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
    noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)
    notebooks = noteStore.listNotebooks(@session[:authtoken])
  end

  # 公開済みノートブック
  opend_books = []
  select = db.blog.project(db.blog[:notebook])
  select.where(db.blog[:user_id].eq(@session[:user_id]))
  query select.to_sql do |sql|
    db.execute sql do |row|
      opend_books << row[:notebook]
    end
  end

  data = {}
  data[:notebooks] = []
  notebooks.each do |notebook|
    notebookData = {
      notebookName: notebook.name.force_encoding("UTF-8"),
      notebookGuid: notebook.guid
    }
    notebookData[:available] = true if notebook.published and opend_books.include?(notebook.guid).!
    data[:notebooks] << notebookData
  end

  ##
  # post された時のチェックに使う
  # tiketのようなもの
  availables = {}
  data[:notebooks].each do |notebook|
    next if notebook[:available].!
    availables[notebook[:notebookGuid]] = notebook[:notebookName]
  end
  env["rack.session"][:notebooks] = availables

  body data.to_json
end

##
# 設定
get "/config/:blog_id" do |blog_id|
  sleep 1

  select = db.blog.project(SqlLiteral.new "*")
  select.where(db.blog[:user_id].eq @session[:user_id])
  select.where(db.blog[:blog_id].eq blog_id)
  row = query select.to_sql do |sql|
    db.get_first_row sql
  end
  raise Forbidden if row.!

  body row.to_json
end

##
# blogidのチェック
get "/check/blogid/:blog_id" do |blog_id|
  select = db.blog.project(db.blog[:blog_id])
  select.where(db.blog[:blog_id].eq blog_id)
  check = query select.to_sql do |sql|
    db.get_first_value sql
  end

  body({available: check.!}.to_json)
end

post "/open" do
  raise Forbidden if env["rack.session"][:notebooks].!
  notebooks    = env["rack.session"][:notebooks]
  raise Forbidden if params["notebookGuid"].!
  notebookGuid = params['notebookGuid']
  raise Forbidden if notebooks[notebookGuid].!
  notebookName = notebooks[notebookGuid]
  raise Forbidden if params["domain"].!
  raise Forbidden if params["subdomain"].!
  blog_id      = params["subdomain"] + '.' + params["domain"]
  raise Forbidden if blog_id !~ /^(([0-9a-z]+[.-])+)?[0-9a-z]+$/
  select = db.blog.project(db.blog[:blog_id])
  select.where(db.blog[:blog_id].eq blog_id)
  check = query select.to_sql do |sql|
    db.get_first_value sql
  end
  raise Forbidden if check

  insert = db.blog.insert_manager
  insert.insert([
                  [db.blog[:user_id], @session[:user_id]],
                  [db.blog[:blog_id], blog_id],
                  [db.blog[:title],   notebookName],
                  [db.blog[:author],  blog_id]
                ])
  query insert.to_sql do |sql|
    db.execute sql
  end

  sleep 3

  200
end

put '/config/:blog_id' do |blog_id|
  update = UpdateManager.new Table.engine
  update.table db.blog
  update.where(db.blog[:user_id].eq @session[:user_id])
  update.where(db.blog[:blog_id].eq blog_id)
  update.set([
               [db.blog[:title],  params["title"]],
               [db.blog[:author], params["author"]]
             ])
  query update.to_sql do |sql|
    db.transaction do
      db.execute sql
      raise Forbidden if (db.changes >= 1).!
    end
  end

  sleep 3
  200
end

# ブログを削除
delete "/close/:blogid" do |blogid|
  query do
    @db.transaction do
      @db.execute @ext.sql_http(:deleteBlog), blogid, @userId
      raise Forbidden if 0 == @db.changes
    end
  end

  # publish.syncに削除済みフラグを付ける
  query do
    @db.execute @ext.sql_http(:close), blogid
  end

  # エイリアスを削除
  path = "%s/%s/%s" % [PUBLIC_ROOT, blogid.slice(0, 2), blogid]
  FileUtils.remove_entry_secure path

  sleep 1
  200
end

# 同期リクエスト
put "/sync/:blogid" do |blogid|
  raise Forbidden if @io.get_blog(blogid, @userId).!

  queued = query do
    queued = false
    @db.transaction do
      @db.execute @ext.sql_http(:sync), blogid:blogid
      queued = 0 != @db.changes
    end
    queued
  end

  sleep 1
  {queued: queued}.to_json
end

delete "/logout" do
  @io.delete_sid
  "http://#{SERVICE_HOST}"
end

def sleep wait
  fb = Fiber.current
  logger.debug "sleep wait:#{wait}"
  EM.add_timer wait do
    fb.resume
  end
  Fiber.yield
end

def query *args, &block
  logger.debug args[0]

  num = 0
  fb = Fiber.current
  tick = proc do
    EM.next_tick do
      begin
        res = block.call *args
      rescue SQLite3::BusyException, SQLite3::LockedException
        num += 1
        p "tick:#{num}"
        tick.call
      rescue Exception => e
        fb.resume e
      else
        fb.resume res
      end
    end
  end
  tick.call
  res = Fiber.yield
  raise res if res.kind_of?(Exception)
  res
end

def thread &block
  fb = Fiber.current
  EM.
    defer(
    EM.Callback do
            begin
              block.call
            rescue Exception => e
              e
            end
          end,
    EM.Callback { |e| fb.resume e })
  e = Fiber.yield
  raise e if e.kind_of? Exception
  e
end

