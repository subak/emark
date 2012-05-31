# -*- coding: utf-8; -*-

Bundler.require :default

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

ActiveRecord::Base.configurations = YAML.load(File.read "./db/config.yml")
ActiveRecord::Base.establish_connection :test

include Arel
Table.engine = ActiveRecord::Base

##
# sinatra

configure do
  disable :show_exceptions
  set :db, ActiveRecord::Base.connection.raw_connection
  set :tbl_a, Table.new(:tbl_a)

  @@ext = Subak::Extsource.new
  @@ext.parser:sql, Subak::Parser::Sql
  @@ext.source:sql, :http, "#{PROJECT_ROOT}/app/assets/sql/http.sql"
  @@db  = SQLite3::Database.new "#{PROJECT_ROOT}/db/http.db"
  @@db.execute "ATTACH DATABASE '#{PROJECT_ROOT}/db/publish.db' AS publish"
  @@db.busy_timeout 1000
end

helper do

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


get "/" do

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


