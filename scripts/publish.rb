#!/usr/bin/env ruby

require "bundler"
Bundler.require :daemon
require "daemons"

Daemons.run("./app/workers/publish/run.rb",
        :app_name   => "publish",
        :dir        => "../../../tmp",
        :log_dir    => File.expand_path("./log"),
        :log_output => true)

