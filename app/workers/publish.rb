#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "fiber"
require "pp"
require "logger"
require "yaml"
require "bundler"
Bundler.require :default, :publish

$: << "./lib/Evernote/EDAM"
require 'note_store'
require 'limits_constants'
require "user_store"
require "user_store_constants.rb"
require "errors_types.rb"

require "./lib/override/sqlite3"
require "./config/environment"

require "./app/workers/blog"

include Emark
include Arel

ActiveRecord::Base.configurations = YAML.load(File.read "./db/config.yml")
ActiveRecord::Base.establish_connection config.environment
Table.engine = ActiveRecord::Base

db = ActiveRecord::Base.connection.raw_connection
db.busy_handler do
  fb = Fiber.current
  EM.add_timer do
    fb.resume true
  end
  Fiber.yield
end

Vars = {}
Vars[:db_blog_q]  = Table.new(:blog_q)
Vars[:db_entry_q] = Table.new(:entry_q)
Vars[:db_meta_q]  = Table.new(:meta_q)
Vars[:db_session] = Table.new(:session)
Vars[:db_blog]    = Table.new(:blog)
Vars[:db_sync]    = Table.new(:sync)
def db.blog_q
  Vars[:db_blog_q]
end
def db.entry_q
  Vars[:db_entry_q]
end
def db.meta_q
  Vars[:db_meta_q]
end
def db.session
  Vars[:db_session]
end
def db.blog
  Vars[:db_blog]
end
def db.sync
  Vars[:db_sync]
end

logger = Logger.new(STDOUT)
logger.level = config.logger_level
Vars[:logger] = logger

blog = Emark::Publish::Blog.new db, logger

def run
  begin
    yield
  rescue Exception => e
    Vars[:logger].debug "#{e}"
  end
end

EM.run do
  EM.add_periodic_timer do
    run do
      blog.run
    end
  end

  # EM.add_periodic_timer do
  #   run do
  #     entry.run
  #   end
  # end

  # EM.add_periodic_timer do
  #   run do
  #     meta.run
  #   end
  # end
end

