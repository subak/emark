#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

run_dir  = File.dirname File.expand_path(__FILE__)
run_root = File.join run_dir, "../../"
Dir::chdir run_root
require File.join run_dir, "publish"
require File.join run_dir, "blog"
require File.join run_dir, "entry"
require File.join run_dir, "meta"

include Emark::Publish

EM.threadpool_size = 120

logger.level = Logger::INFO

EM.run do
  reset = Reset.new
  reset.run 0

  queue Blog,  10
  queue Entry, 100
  queue Meta,  10

  EM.add_periodic_timer 300 do
    reset.run 300
  end
end
