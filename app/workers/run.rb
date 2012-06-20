#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

$: << "./lib"

dir = File.dirname File.expand_path(__FILE__)
require File.join dir, "publish"
require File.join dir, "blog"
require File.join dir, "entry"
require File.join dir, "meta"

def run &block
  begin
    Fiber.new do
      block.call
    end.resume
  rescue Emark::Publish::Fatal => e
    logger.debug "#{e}"
  rescue Exception => e
    logger.debug e
  end
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

      EM.add_periodic_timer 0.5 do
        run do
          Emark::Publish::Meta.run
        end
      end
    end
  end
end

EM.run do
  scope
  EM.add_periodic_timer 300 do
    delete_expired_queue_blog
    delete_expired_queue_entry
    delete_expired_queue_meta
  end
end
