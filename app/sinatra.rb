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
  logger.warn env['sinatra.error']
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
  elsif request.path != "/"
    halt 403
  end
end

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

  # data = {}
  # data[:available] = @io.blog_exists?(blogid) ? false : true
  # body data.to_json
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
      else
        fb.resume res
      end
    end
  end
  tick.call
  Fiber.yield
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


__END__

before do
  logger.level = config.logger_level

  if request.path =~ %r{^(/dashboard|/open|/logout|/config/[^/]+|/close/[^/]+|/check/blogid/[^/]+|/sync/[^/]+)$}
    raise Forbidden if not @session = @io.get_session
    @userId = @session[:userId]
  end
end

after do
  headers 'Content-Type' => 'application/json; charset=utf-8'
end

get "/" do
  if oauthVerifier = request.params['oauth_verifier']
    status = access_token oauthVerifier
    body "/"
  elsif vars = @io.get_session
    body '/dashboard'
  else
    body request_token "/"
  end
end

get "/dashboard" do
  blogs = []
  @io.get_blogs(@userId).each do |blogid, var|
    blogs << var
  end

  sleep 1

  body({blogs: blogs}.to_json)
end

get "/open" do
  sleep 1
  body open.to_json
end

post "/open" do
  notebooks    = @io.get_session_notebooks
  notebookGuid = params['notebookGuid']
  notebookName = notebooks[notebookGuid]
  blogid       = params["subdomain"] + '.' + params["domain"]

  raise Forbidden if notebookName.!
  raise Forbidden if blogid !~ /^(([0-9a-z]+[.-])+)?[0-9a-z]+$/
  raise Forbidden if @io.blog_exists? blogid

  @io.set_blog notebookGuid, blogid, @userId

  config = {
    title:  notebookName,
    author: blogid
  }
  @io.set_blog_config config, blogid, @userId

  sleep 3

  200
end

get "/config/:blogid" do |blogid|
  raise Forbidden if not blog = @io.get_blog(blogid, @userId)
  sleep 1
  body blog.to_json
end

put '/config/:blogid' do |blogid|
  @io.set_blog_config params, blogid, @userId
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

# blogidのチェック
get "/check/blogid/:blogid" do |blogid|
  data = {}
  data[:available] = @io.blog_exists?(blogid) ? false : true
  body data.to_json
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

def query *args, &block
  begin
    block.call *args
  rescue SQLite::Exceptions::BusyException, SQLite::Exceptions::LockedException
    retry
  end
end

def sleep wait
  fb = Fiber.current
  puts "sleep wait:#{wait}"
  EM.add_timer wait do
    fb.resume
  end
  Fiber.yield
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

def request_token redirectPath
  callbackUrl = URI::Generic.build(
                             scheme: SERVICE_SCHEME,
                             host:   SERVICE_HOST,
                             port:   SERVICE_PORT,
                             path:   redirectPath)

  consumer = OAuth::Consumer.
    new(
    EVERNOTE_OAUTH_CONSUMER_KEY,
    EVERNOTE_OATUH_CONSUMER_SECRET,
    site:               EVERNOTE_SITE,
    request_token_path: "/oauth",
    access_token_path:  "/oauth",
    authorize_path:     "/OAuth.action")


  request_token = thread do
    consumer.get_request_token(:oauth_callback => callbackUrl)
  end

  @io.set_sid
  @io.set_request_token request_token

  request_token.authorize_url
end

def access_token oauthVerifier
  request_token = @io.get_request_token
  raise Forbidden, "request_token" if request_token.!

  access_token = thread do
    request_token.get_access_token oauth_verifier: oauthVerifier
  end

  user = thread do
    userStoreTransport = Thrift::HTTPClientTransport.new("#{EVERNOTE_SITE}/edam/user")
    userStoreProtocol = Thrift::BinaryProtocol.new(userStoreTransport)
    userStore = Evernote::EDAM::UserStore::UserStore::Client.new(userStoreProtocol)
    userStore.getUser access_token.params['oauth_token']
  end

  vars = {
    userId:          user.id,
    username:        user.username,
    shard:           user.shardId,
    noteStoreUrl:    access_token.params['edam_noteStoreUrl'],
    webApiUrlPrefix: access_token.params['edam_webApiUrlPrefix'],
    authToken:       access_token.params['oauth_token'],
    expires:         access_token.params['edam_expires'],
  }

  vars[:sid] = @io.set_sid (vars[:expires].to_i/1000).to_i
  @io.update_session vars

  200
end

def open
  notebooks = thread do
    noteStoreTransport = Thrift::HTTPClientTransport.new(@session[:noteStoreUrl])
    noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
    noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)
    notebooks = noteStore.listNotebooks(@session[:authToken])
  end

  ###
  # postされたnotebookGuidのチェック
  # notebookNameの取得
  forSession = {}
  notebooks.each do |notebook|
    forSession[notebook.guid] = notebook.name
  end
  @io.set_session_notebooks forSession

  # 公開済みノートブック
  usedBooks = []
  @io.get_blogs(@io.get_session[:userId]).each do |blogid, vars|
    usedBooks.push vars[:notebookGuid]
  end

  data = {}
  data[:notebooks] = []
  notebooks.each do |notebook|
    notebookData = {
      notebookName: notebook.name.force_encoding('UTF-8'),
      notebookGuid: notebook.guid
    }
    if notebook.published and !usedBooks.include?(notebook.guid)
      notebookData[:available] = true
    end
    data[:notebooks] << notebookData
  end

  data
end


