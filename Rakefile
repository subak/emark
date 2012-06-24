# -*- coding: utf-8 -*-

require "pp"

namespace:assets do
  namespace:haml do
    def haml from, to
      require "bundler"
      Bundler.require :assets
      require "./config/environment"

      FileUtils.mkdir_p File.dirname(to)

      File.open to, "w" do |fp|
        fp.write Haml::Engine.new(File.read(from), :format => :html5).render
      end
      puts "write to #{to}"
    end

    desc "assets:haml:octopress"
    task:octopress do
      from = "app/views/layouts/octopress.haml"
      to   = "public/emark.jp/octopress/index.html"
      haml from, to
    end

    desc "dashboard"
    task:dashboard do
      from = "app/views/layouts/dashboard.haml"
      to   = "public/emark.jp/dashboard/index.html"
      haml from, to
    end
  end


  desc "assets:sprockets"
  task:sprockets do
    require "bundler"
    Bundler.require :assets

    vendors = []

    $:.each do |path|
      next if path !~ /\/lib$/
      ["/vendor/assets/javascripts", "/app/assets/javascripts"].each do |suffix|
        vendor = path.sub /\/lib$/, suffix
        vendors << vendor if File.exist? vendor
      end
    end

    environment = Sprockets::Environment.new
    vendors.each do |vendor|
      environment.append_path vendor
      environment.append_path "app/assets/javascripts"
    end

    targets = {
      "octopress.js.coffee" => "public/emark.jp/octopress/index.js",
      "dashboard.js.coffee" => "public/emark.jp/dashboard/index.js"
    }

    targets.each do |from, to|
      File.open to, "w" do |fp|
        fp.write environment[from].to_s
      end
      puts "write to #{to}"
    end
  end

  namespace:sprockets do
    desc "assets:sprockets:fsevent"
    task:fsevent do
      require "bundler"
      Bundler.require :assets

      fsevent = FSEvent.new
      fsevent.watch ["app/assets/javascripts"] do
        begin
          Rake::Task["assets:sprockets"].execute
        rescue Exception => e
          pp e.backtrace
        end
      end
      fsevent.run
    end
  end

  desc "auto"
  task:auto do
    require "bundler"
    Bundler.require :assets

    fsevent = FSEvent.new
    fsevent.watch ["app/assets/javascripts", "app/views"] do |path|
      begin
        if path[0] =~ %r{app/assets/javascripts}
          Rake::Task["assets:sprockets"].execute
        end

        if path[0] =~ %r{app/views}
          Rake::Task["assets:haml:octopress"].execute
          Rake::Task["assets:haml:dashboard"].execute
        end
      rescue Exception => e
        pp e.backtrace
      end
    end
    fsevent.run
  end
end


namespace:build do
  desc "config_js"
  task:config_js do
    require "erb"
    require "./config/environment"

    path = "app/assets/javascripts/config.js"
    erb  = ERB.new File.read("./config/config.js.erb")

    File.open path, "w" do |fp|
      fp.write erb.result
    end

    puts "write to #{path}"
  end

  desc "nginx"
  task:nginx do
    require "erb"
    require "./config/environment"

    erb = ERB.new File.read("./config/emark.conf.erb")
    File.open config.nginx_conf, "w" do |f|
      f.puts erb.result
    end
    puts "write to #{config.nginx_conf}"
  end
end

desc "build"
task:build do
  Rake::Task["build:config_js"].execute
  Rake::Task["build:nginx"].execute
end


task :default => :spec

desc "spec"
task:spec do
  sh "bundle exec rake db:migrate RAILS_ENV=test"
  sh 'rspec -cfs -P "spec/publish/*_spec.rb"'
end

begin
  require 'tasks/standalone_migrations'
rescue LoadError => e
  puts "gem install standalone_migrations to get db:migrate:* tasks! (Error: #{e})"
end


__END__



begin
  require 'tasks/standalone_migrations'
rescue LoadError => e
  puts "gem install standalone_migrations to get db:migrate:* tasks! (Error: #{e})"
end

begin
  require 'jasmine'
  load 'jasmine/tasks/jasmine.rake'
rescue LoadError
  task :jasmine do
    abort "Jasmine is not available. In order to run jasmine, you must: (sudo) gem install jasmine"
  end
end

desc "jspec"
task:jspec do
  sh "bundle exec jasmine-headless-webkit -c"
end

namespace :rspec do
  namespace :publish do
    begin
      require "pp"
      require "rb-fsevent"
    rescue LoadError
      puts "rspec:publish can't load rb-fsevent"
    end

    desc "rspec:publish:blog"
    task :blog do
      sh "rspec spec/publish/blog_spec.rb -cfs"
      fsevent = FSEvent.new
      fsevent.watch ["spec/publish", "app/workers"], ["--latency", "1.5"] do
        begin
          sh "rspec spec/publish/blog_spec.rb -cfs"
        rescue Exception => e
          pp e.backtrace
        end
      end
      fsevent.run
    end

    desc "rspec:publish:entry"
    task :entry do
      sh "rspec spec/publish/entry_spec.rb -cfs"
      fsevent = FSEvent.new
      fsevent.watch ["spec/publish", "app/workers"], ["--latency", "1.5"] do
        begin
          sh "rspec spec/publish/entry_spec.rb -cfs"
        rescue Exception => e
          pp e.backtrace
        end
      end
      fsevent.run
    end

    desc "rspec:publish:meta"
    task :meta do
      sh "rspec spec/publish/meta_spec.rb -cfs"
      fsevent = FSEvent.new
      fsevent.watch ["spec/publish", "app/workers"], ["--latency", "1.5"] do
#        begin
          sh "rspec spec/publish/meta_spec.rb -cfs"
        # rescue Exception => e
        #   pp e.backtrace
        # end
      end
      fsevent.run
    end
  end
end

namespace:haml do
  begin
    require "pp"
    require "rb-fsevent"
    require "haml"
    require "./config/environment"
  rescue LoadError
    puts "rspec:publish can't load rb-fsevent"
  end

  desc "haml:octopress"
  task:octopress do
    octopress = "public/emark.jp/octopress/index.html"
    File.open octopress, "w" do |fp|
      fp.write Haml::Engine.new(File.read("app/views/layouts/octopress.haml"), :format => :html5).render
    end
    puts "write to #{octopress}"
  end

  desc "haml:dashboard"
  task:dashboard do
  end

  desc "haml:fsevent"
  task:fsevent do
    fsevent = FSEvent.new
    fsevent.watch ["app"] do
      begin
        Rake::Task["haml:octopress"].execute
      rescue Exception => e
        pp e.backtrace
      end
    end
    fsevent.run
  end
end

