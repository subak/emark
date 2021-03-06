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
use Rack::FiberPool , :size => 100
use Rack::Session::Cookie, {
  :http_only => true,
  :secure    => true
}

ActiveRecord::Base.configurations = YAML.load(File.read "./db/config.yml")
ActiveRecord::Base.establish_connection config.environment
include Arel
Table.engine = ActiveRecord::Base

require "./app/helpers/emark"
include Emark

##
# sinatra
configure do
  disable :show_exceptions
  set :environment, config.environment
end

helpers do
  def db
    @db
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

  @db      = connection
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

# token
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


# index
get "/blogs" do
  sleep 0.5
  select = db.blog.project(SqlLiteral.new "*")
  select.where(db.blog[:uid].eq @session[:uid])
  db.execute(select.to_sql).to_json
end


# open
post "/blogs" do
  params = JSON.parse(request.body.read)

  raise Forbidden if env["rack.session"][:notebooks].!
  notebooks    = env["rack.session"][:notebooks]
  raise Forbidden if params["notebook"].!
  notebook     = params["notebook"]
  raise Forbidden if notebooks[notebook].!
  notebookName = notebooks[notebook]
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
  id = nil
  db.transaction do
    db.execute insert.to_sql
    id = db.last_insert_row_id
    raise Fatal if id.!
  end

  sleep 1
  env["rack.session"][:notebooks] = nil

  select = db.blog.project(SqlLiteral.new "*")
  select.where(db.blog[:id].eq id)
  blog = db.get_first_row select.to_sql

  blog.to_json
end


# config
put "/blogs/:bid" do |bid|
  params = JSON.parse(request.body.read)
  params["about_me"]            = nil if "" == params["about_me"]
  params["twitter_tweet_count"] = nil if "" == params["twitter_tweet_count"]

  update = UpdateManager.new Table.engine
  update.table db.blog
  update.where(db.blog[:uid].eq @session[:uid])
  update.where(db.blog[:bid].eq  bid)
  update.set([
               [db.blog[:title],               params["title"]],
               [db.blog[:subtitle],            params["subtitle"]],
               [db.blog[:author],              params["author"]],
               [db.blog[:paginate],            params["paginate"]],
               [db.blog[:recent_posts],        params["recent_posts"]],
               [db.blog[:excerpt_count],       params["excerpt_count"]],
               [db.blog[:about_me],            params["about_me"]],
               [db.blog[:disqus_short_name],   params["disqus_short_name"]],
               [db.blog[:twitter_user],        params["twitter_user"]],
               [db.blog[:twitter_tweet_count], params["twitter_tweet_count"]]
             ])
  db.transaction do
    begin
      db.execute update.to_sql
    rescue SQLite3::ConstraintException
      raise Forbidden
    end
    raise Forbidden if (db.changes == 1).!
  end

  sleep 1
  200
end


# close
delete "/blogs/:bid" do |bid|
  db.transaction do
    delete = DeleteManager.new Table.engine
    delete.from db.blog
    delete.where(db.blog[:uid].eq @session[:uid])
    delete.where(db.blog[:bid].eq bid)
    db.execute delete.to_sql
    raise Forbidden if (db.changes == 1).!

    # publish.syncに削除済みフラグを付ける
    update = UpdateManager.new Table.engine
    update.table db.sync
    update.set([
                 [db.sync[:deleted], 1]
               ])
    update.where(db.sync[:bid].eq bid)
    db.execute update.to_sql
  end

  # エイリアスを削除
  # ディレクトリごと削除
  path = File.join(config.public_blog, bid.slice(0, 2), bid)
  FileUtils.remove_entry_secure(path) if File.exist?(path)

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

  body data[:notebooks].to_json
end



# check
get "/check/bid" do
  bid = params[:bid]
  raise Forbidden if bid.!
  select = db.blog.project(db.blog[:bid])
  select.where(db.blog[:bid].eq bid)
  sql = select.to_sql;
  check = db.get_first_value sql

  "#{check.!}"
end


# sync
get "/sync/:bid" do |bid|
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
  {
    id:     bid,
    queued: queued
  }.to_json
end


# logout
# sidを付ける意味があるのか？
delete "/logout/:sid" do |sid|
  raise Fatal if @session[:sid] != sid

  delete = DeleteManager.new Table.engine
  delete.from db.session
  delete.where(db.session[:uid].eq @session[:uid])
  db.transaction do
    db.execute delete.to_sql
    raise Forbidden if (db.changes >= 1).!
  end

  {
    location: config.site_href
  }.to_json
end
