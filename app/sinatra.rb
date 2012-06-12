# -*- coding: utf-8 -*-

require "pp"
require "digest/md5"
require "json"
Bundler.require :default, :http
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
  :secure    => true
}

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
  set :db_blog_q,  Table.new(:blog_q)
  set :db_sync,    Table.new(:sync)

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

  def db.sync
    settings.db_sync
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
    @session = db.get_first_row select.to_sql

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

    select = db.session.project db.session[:uid]
    select.where(db.session[:uid].eq user.id)
    res = db.get_first_value select.to_sql

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
                        [db.session[:uid],   user.id],
                        [db.session[:shard],     user.shardId],
                        [db.session[:authtoken], accessToken.params[:oauth_token]],
                        [db.session[:expires],   expires],
                        [db.session[:sid],       sid]
                      ])
        insert
      end

    db.execute manager.to_sql

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

get "/blogs" do
  sleep 0.5
  select = db.blog.project(SqlLiteral.new "*")
  select.where(db.blog[:uid].eq @session[:uid])
  db.execute(select.to_sql).to_json
end

post "/blogs" do
  params = JSON.parse(request.body.read)
  pp params

  raise Forbidden if env["rack.session"][:notebooks].!
  notebooks    = env["rack.session"][:notebooks]
  raise Forbidden if params["notebook"].!
  notebook     = params["notebook"]
  raise Forbidden if notebooks[notebook].!
  notebookName = notebooks[notebook]
  # raise Forbidden if params["domain"].!
  # raise Forbidden if params["subdomain"].!
  # blog_id      = params["subdomain"] + '.' + params["domain"]
  bid          = params["bid"]
  raise Forbidden if bid !~ /^(([0-9a-z]+[.-])+)?[0-9a-z]+$/
  select = db.blog.project(db.blog[:bid])
  select.where(db.blog[:bid].eq bid)
  raise Forbidden if db.get_first_value(select.to_sql)

  insert = db.blog.insert_manager
  insert.insert([
                  [db.blog[:bid],      bid],
                  [db.blog[:uid],      @session[:uid]],
                  [db.blog[:notebook], notebook],
                  [db.blog[:title],    notebookName],
                  [db.blog[:author],   bid]
                ])
  db.execute insert.to_sql

  sleep 1
  env["rack.session"][:notebooks] = nil

  200
end

put "/blogs/:id" do |id|
  params = JSON.parse(request.body.read)
  update = UpdateManager.new Table.engine
  update.table db.blog
  update.where(db.blog[:uid].eq @session[:uid])
  update.where(db.blog[:id].eq id)
  update.set([
               [db.blog[:title],    params["title"]],
               [db.blog[:subtitle], params["subtitle"]],
               [db.blog[:author],   params["author"]]
             ])
  db.transaction do
    db.execute update.to_sql
    raise Forbidden if (db.changes >= 1).!
  end

  sleep 1
  200
end


get "/notebooks" do
  notebooks = thread do
    noteStoreTransport = Thrift::HTTPClientTransport.new("#{config.evernote_site}/edam/note/#{@session[:shard]}")
    noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
    noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)
    notebooks = noteStore.listNotebooks(@session[:authtoken])
  end

  # 公開済みノートブック
  opend_books = []
  select = db.blog.project(db.blog[:notebook])
  select.where(db.blog[:uid].eq(@session[:uid]))

  db.execute select.to_sql do |row|
    opend_books << row[:notebook]
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





get "/dashboard" do
  sleep 1

  blogs = []
  select = db.blog.project(SqlLiteral.new "*")
  select.where(db.blog[:uid].eq @session[:uid])

  db.execute select.to_sql do |row|
    blogs << row
  end

  body({blogs: blogs}.to_json)
end

get "/config" do
  select = db.blog.project(SqlLiteral.new "*")
  select.where(db.blog[:uid].eq @session[:uid])

  db.execute(select.to_sql).to_json
end

##
# 設定
get "/config/:blog_id" do |blog_id|
  sleep 1

  select = db.blog.project(SqlLiteral.new "*")
  select.where(db.blog[:uid].eq @session[:uid])
  select.where(db.blog[:bid].eq blog_id)
  row = db.get_first_row select.to_sql
  raise Forbidden if row.!

  body row.to_json
end

##
# bidのチェック
get "/check/bid" do
  bid = params[:bid]
  raise Forbidden if bid.!
  select = db.blog.project(db.blog[:bid])
  select.where(db.blog[:bid].eq bid)
  check = db.get_first_value select.to_sql

  "#{check.!}"
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
  select = db.blog.project(db.blog[:bid])
  select.where(db.blog[:bid].eq blog_id)
  check = db.get_first_value select.to_sql
  raise Forbidden if check

  insert = db.blog.insert_manager
  insert.insert([
                  [db.blog[:uid], @session[:uid]],
                  [db.blog[:bid], blog_id],
                  [db.blog[:title],   notebookName],
                  [db.blog[:author],  blog_id]
                ])
  db.execute insert.to_sql

  sleep 3
  env["rack.session"][:notebooks] = nil

  200
end

put "/config/:id" do |id|
  params = JSON.parse(request.body.read)

  update = UpdateManager.new Table.engine
  update.table db.blog
  update.where(db.blog[:uid].eq @session[:uid])
  update.where(db.blog[:id].eq id)
  update.set([
               [db.blog[:title],    params["title"]],
               [db.blog[:subtitle], params["subtitle"]],
               [db.blog[:author],   params["author"]]
             ])
  db.transaction do
    db.execute update.to_sql
    raise Forbidden if (db.changes >= 1).!
  end

  sleep 1
  200
end


# put '/config/:bid' do |bid|
#   pp params
#   pp request
#   payload = request.body.read
#   data = JSON.parse(payload)
#   pp data

#   update = UpdateManager.new Table.engine
#   update.table db.blog
#   update.where(db.blog[:uid].eq @session[:uid])
#   update.where(db.blog[:bid].eq bid)
#   update.set([
#                [db.blog[:title],  params["title"]],
#                [db.blog[:author], params["author"]]
#              ])
#   db.transaction do
#     db.execute update.to_sql
#     raise Forbidden if (db.changes >= 1).!
#   end

#   sleep 3
#   200
# end

# ブログを削除
delete "/close/:bid" do |bid|
  delete = DeleteManager.new Table.engine
  delete.from db.blog
  delete.where(db.blog[:uid].eq @session[:uid])
  delete.where(db.blog[:bid].eq bid)
  db.transaction do
    db.execute delete.to_sql
    raise Forbidden if (db.changes >= 1).!
  end

  # publish.syncに削除済みフラグを付ける
  update = UpdateManager.new Table.engine
  update.table db.sync
  update.set([
               [db.sync[:deleted], 1]
             ])
  update.where(db.sync[:bid].eq bid)
  db.execute update.to_sql

  # エイリアスを削除
  # ディレクトリごと削除
  path = File.join(config.public_blog, bid.slice(0, 2), bid)
  FileUtils.remove_entry_secure(path) if File.exist?(path)

  sleep 1
  200
end

# 同期リクエスト
post "/sync/:bid" do |bid|
  select = db.blog.project(db.blog[:bid])
  select.where(db.blog[:uid].eq @session[:uid])
  select.where(db.blog[:bid].eq bid)
  check = db.get_first_value select.to_sql
  raise Forbidden if check.!

  select = db.blog_q.project(db.blog_q[:bid])
  select.where(db.blog_q[:bid].eq bid)
  check = db.get_first_value select.to_sql
  queued = false
  if check.!
    insert = db.blog_q.insert_manager
    insert.insert([
                    [db.blog_q[:bid],    bid],
                    [db.blog_q[:queued], Time.now.to_f]
                  ])
    db.transaction do
      db.execute insert.to_sql
      queued = db.changes >= 1
    end
  end

  sleep 1
  {queued: queued}.to_json
end

delete "/logout" do
  delete = DeleteManager.new Table.engine
  delete.from db.session
  delete.where(db.session[:uid].eq @session[:uid])
  db.transaction do
    db.execute delete.to_sql
    raise Forbidden if (db.changes >= 1).!
  end

  config.site_href
end

def sleep wait
  fb = Fiber.current
  logger.debug "sleep wait:#{wait}"
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
