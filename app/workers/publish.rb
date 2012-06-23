# -*- coding: utf-8 -*-

require "fiber"
require "pp"
require "logger"
require "yaml"
require "digest"
require "bundler"
Bundler.require :default, :publish

require "./config/environment"

include Emark
$: << "./lib/Evernote/EDAM"
require 'note_store'
require 'limits_constants'
require "user_store"
require "user_store_constants.rb"
require "errors_types.rb"

require "subak/utility"

require "./lib/override/sqlite3"

ActiveRecord::Base.configurations = YAML.load(File.read "./db/config.yml")
ActiveRecord::Base.establish_connection config.environment
include Arel
Table.engine = ActiveRecord::Base

Scope = {vars: {}}
def scope
  ActiveRecord::Base.establish_connection config.environment
  db = ActiveRecord::Base.connection.raw_connection
  db.busy_handler do |resouce, retries|
    logger.info "busy"
    fb = Fiber.current
    EM.add_timer do
      fb.resume true
    end
    Fiber.yield
  end

  def db.blog_q
    Table.new(:blog_q)
  end

  def db.entry_q
    Table.new(:entry_q)
  end

  def db.meta_q
    Table.new(:meta_q)
  end

  def db.session
    Table.new(:session)
  end

  def db.blog
    Table.new(:blog)
  end

  def db.sync
    Table.new(:sync)
  end

  logger = Logger.new(STDOUT)
  logger.level = config.logger_level

  Scope[:vars] = {
    db:     db,
    logger: logger
  }
end

def db
  Scope[:vars][:db]
end

def logger
  Scope[:vars][:logger]
end

def delete_expired_queue_blog limit
  update = UpdateManager.new Table.engine
  update.table db.blog_q
  update.set([
               [db.blog_q[:lock], 0]
             ])
  update.where(db.blog_q[:lock].eq 1)
  update.where db.blog_q[:queued].lt(Time.now.to_f - limit)
  sql = update.to_sql
  db.execute sql
  logger.info sql if db.changes >= 1

end

def delete_expired_queue_entry limit
  delete = DeleteManager.new Table.engine
  delete.from db.entry_q
  delete.where(db.entry_q[:lock].eq 1)
  delete.where db.entry_q[:queued].lt(Time.now.to_f - limit)
  sql = delete.to_sql; logger.info sql
  db.execute sql
  logger.info sql if db.changes >= 1

  # update = UpdateManager.new Table.engine
  # update.table db.entry_q
  # update.set([
  #              [db.entry_q[:lock], 0]
  #            ])
  # update.where(db.entry_q[:lock].eq 1)
  # update.where db.entry_q[:queued].lt(Time.now.to_f - limit)
  # sql = update.to_sql; logger.debug sql
  # db.execute sql
end

def delete_expired_queue_meta limit
  update = UpdateManager.new Table.engine
  update.table db.meta_q
  update.set([
               [db.meta_q[:lock], 0]
             ])
  update.where(db.meta_q[:lock].eq 1)
  update.where db.meta_q[:queued].lt(Time.now.to_f - limit)
  sql = update.to_sql
  db.execute sql
  logger.info sql if db.changes >= 1
end

module Emark
  module Publish
    class Empty < Exception; end
    class Fatal < Exception; end

    private
    def session bid
      select = db.session.project(SqlLiteral.new "*")
      select.join(db.blog).on(db.session[:uid].eq db.blog[:uid])
      select.where(db.blog[:bid].eq bid)
      select.take 1

      sql = select.to_sql; logger.debug sql
      session = db.get_first_row sql
      raise Fatal if session.!
      session
    end
  end
end
