#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

$: << "./lib"

dir = File.dirname File.expand_path(__FILE__)
require File.join dir, "publish"
require File.join dir, "blog"
require File.join dir, "entry"
require File.join dir, "meta"

def run &block
  Fiber.new do
    begin
      block.call
    rescue SQLite3::LockedException, SQLite3::BusyException => e
      logger.debug "#{e}"
    rescue Emark::Publish::Fatal => e
      logger.debug "#{e}"
    rescue Exception => e
      logger.debug e
    end
  end.resume
end

config.cpu_core.times do
  Thread.new do
    scope
    EM.run do
      EM.add_periodic_timer 0.1 do
        run do
          Emark::Publish::Blog.run
        end
      end

      EM.add_periodic_timer 0.1 do
        run do
          Emark::Publish::Entry.run
        end
      end

      EM.add_periodic_timer 1 do
        run do
          Emark::Publish::Meta.run
        end
      end
    end
  end
end

EM.run do
  scope
  run do
    delete_expired_queue_blog  0
    delete_expired_queue_entry 0
    delete_expired_queue_meta  0
  end
  EM.add_periodic_timer 300 do
    run do
      delete_expired_queue_blog  300
      delete_expired_queue_entry 300
      delete_expired_queue_meta  300
    end
  end
end
