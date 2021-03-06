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

$: << "./lib"
require "subak/utility"

require "./lib/override/sqlite3"

ActiveRecord::Base.configurations = YAML.load(File.read "./db/config.yml")
ActiveRecord::Base.establish_connection config.environment
include Arel
Table.engine = ActiveRecord::Base

module Emark
  module Publish
    class Empty < Exception; end
    class Fatal < Exception; end

    module Common
      def initialize
        db = SQLite3::Database.new ActiveRecord::Base.configurations[config.environment]["database"]
        db.results_as_hash = true
        db.busy_handler do |resouce, retries|
          fb = Fiber.current
          EM.add_timer do
            logger.info "busy"
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

        @db = db
      end

      def db
        @db
      end

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

    class Reset
      include Common

      def run limit
        delete_expired_queue_blog  limit
        delete_expired_queue_entry limit
        delete_expired_queue_meta  limit
      end

      private

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
        sql = delete.to_sql
        db.execute sql
        logger.info sql if db.changes >= 1
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
    end

    private
    def logger
      Emark::Publish.logger
    end

    def sleep time=0
      fb = Fiber.current
      EM.add_timer time do
        fb.resume
      end
      Fiber.yield
    end

    def run q, interval, &block
      q.pop do |obj|
        df = EM::DefaultDeferrable.new
        df.callback do |obj|
          fb = Fiber.current
          EM.add_timer do
            fb.resume
          end
          Fiber.yield

          q.push obj
          2.times do
            run q, interval, &block
          end
        end

        Fiber.new do
          begin
            block.call obj, df
          rescue Emark::Publish::Fatal => e
            logger.warn "#{e}"
          rescue Exception => e
            logger.warn e
          end
        end.resume
      end
    end

    def queue klass, size, interval=0
      q = EM::Queue.new
      size.times { q.push klass.new }
      block = proc do |obj, df|
        df.errback do |obj|
          sleep 1
          q.push obj
          if size == q.size
            run q, interval, &block
          end
        end
        obj.run.! ? df.fail(obj) : df.succeed(obj)
      end
      run q, interval, &block
    end

    class << self
      def logger
        @logger ||= Logger.new(STDOUT){@level = config.logger_level}
      end
    end
  end
end
