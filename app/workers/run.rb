#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

dir = File.dirname File.expand_path(__FILE__)
require File.join dir, "publish"
require File.join dir, "blog"
require File.join dir, "entry"
require File.join dir, "meta"

def run
  begin
    yield
  rescue Exception => e
    logger.debug e
#    logger.debug "#{e}"
  end
end

EM.run do
  EM.add_periodic_timer do
    run do
      Emark::Publish::Blog.run
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

