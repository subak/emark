#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "pp"
require "logger"
require "eventmachine"
require "sqlite3"
require "active_record"
require "yaml"
require "arel"

require "./config/environment"

ActiveRecord::Base.configurations = YAML.load(File.read "./db/config.yml")
ActiveRecord::Base.establish_connection config.environment
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

logger = Logger.new(STDOUT)
logger.level = config.logger_level

blog = Emark::Publish::Blog.new db, logger

EM.run do
  blog.step_1

  puts "hoge"
  EM.stop
end

