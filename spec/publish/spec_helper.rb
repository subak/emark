# -*- coding: utf-8; -*-

require "pp"
require "logger"
require "eventmachine"
require "sqlite3"
require "active_record"
require "active_support"
require "yaml"
require "arel"

require "./lib/override/sqlite3"
require "./config/environment"
include Emark
$: << "./lib/Evernote/EDAM"
require 'note_store'
require 'limits_constants'
require "user_store"
require "user_store_constants.rb"
require "errors_types.rb"

ActiveRecord::Base.configurations = YAML.load(File.read "./db/config.yml")
ActiveRecord::Base.establish_connection :spec
include Arel
Table.engine = ActiveRecord::Base

db = ActiveRecord::Base.connection.raw_connection
db.busy_handler do
  fb = Fiber.current
  EM.add_timer do
    fb.resume true
  end
  Fiber.yield
end

def db.blog_q
  Table.new(:blog_q)
end

def db.session
  Table.new(:session)
end

def db.blog
  Table.new(:blog)
end

logger = Logger.new(STDOUT)
logger.level = config.logger_level

Vars = {}
Vars[:db]     = db
Vars[:logger] = logger

module Helper
  def db
    Vars[:db]
  end

  def logger
    Vars[:logger]
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

  def get_session
    select = db.session.project(SqlLiteral.new "*")
    select.where(db.session[:uid].eq 25512727)
    @session = db.get_first_row select.to_sql
    raise "session error" if @session.!
    @http_cookie = "sid=#{@session[:sid]}"
  end

  def delete_blog
    delete = DeleteManager.new Table.engine
    delete.from db.blog
    db.execute delete.to_sql
  end

  def delete_blog_q
    delete = DeleteManager.new Table.engine
    delete.from db.blog_q
    db.execute delete.to_sql
  end

end
