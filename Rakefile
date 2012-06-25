# -*- coding: utf-8 -*-

require "pp"
require "bundler"

if "test" == ENV["RAILS_ENV"]
  Bundler.require :test
  require "ruby-debug"
  Debugger.start
end

namespace:assets do
  def haml targets
    require "sass/plugin"
    Bundler.require :assets
    require "./config/environment"

    targets.each do |from, to|
      FileUtils.mkdir_p File.dirname(to)

      File.open to, "w" do |fp|
        fp.write Haml::Engine.new(File.read(from), :format => :html5).render
      end
      puts "write to #{to}"
    end
  end

  desc "haml"
  task:haml do
    targets = {
      "app/views/layouts/octopress.haml" => "public/emark.jp/octopress/index.html",
      "app/views/layouts/dashboard.haml" => "public/emark.jp/dashboard/index.html"
    }
    haml targets
  end

  def sprockets targets
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
      environment.append_path "app/assets/stylesheets"
    end

    require "./config/environment"

    targets.each do |from, to|
      File.open to, "w" do |fp|
        fp.write environment[from].to_s
      end
      puts "write to #{to}"
    end
  end


  sprockets = {
    "javascripts" => {
      "octopress" => {
        "octopress.js.coffee" => "public/emark.jp/octopress/index.js"
      },
      "dashboard" => {
        "dashboard.js.coffee" => "public/emark.jp/dashboard/index.js"
      },
    },
    "stylesheets" => {
      "octopress" => {
        "octopress.css.sass" => "public/emark.jp/octopress/index.css"
      },
      "dashboard" => {
        "dashboard.css.sass" => "public/emark.jp/dashboard/index.css"
      }
    }
  }
  namespace:sprockets do
    sprockets.each do |key, value|
      namespace key do
        value.each do |key, value|
          desc key
          task key do
            sprockets value
          end
        end
      end
      desc key
      tasks = value.keys.map do |name|
        "#{key}:#{name}"
      end
      task key do
        tasks.each do |task|
          name = "assets:sprockets:#{task}"
          Rake::Task[name].execute
        end
      end
    end
  end
  desc "sprockets"
  tasks = sprockets.keys.map do |name|
    "sprockets:#{name}"
  end
  task:sprockets do
    tasks.each do |task|
      name = "assets:#{task}"
      Rake::Task[name].execute
    end
  end


  desc "watch"
  task:watch do
    require "sass/plugin"
    Bundler.require :assets

    fsevent = FSEvent.new

    paths = ["app/assets/javascripts", "app/assets/stylesheets", "app/views"]
    options = {
      :latency => 2
    }

    fsevent.watch paths, options do |path|
      begin
        if path[0] =~ %r{app/assets/javascripts}
          if path[0] =~ %r{dashboard}
            Rake::Task["assets:sprockets:javascripts:dashboard"].execute
          end
          if path[0] =~ %r{octopress}
            Rake::Task["assets:sprockets:javascripts:octopress"].execute
          end
        end

        if path[0] =~ %r{app/assets/stylesheets}
          Rake::Task["assets:sprockets:stylesheets"].execute
        end

        if path[0] =~ %r{app/views}
          Rake::Task["assets:haml"].execute
        end
      rescue Exception => e
        pp e
      end
    end
    fsevent.run
  end
end
desc "assets"
task:assets => ["assets:haml", "assets:sprockets"]


namespace:build do
  desc "nginx"
  task:nginx do
    require "erb"
    require "./config/environment"

    erb = ERB.new File.read("./config/nginx.conf.erb")
    File.open config.nginx_conf, "w" do |f|
      f.puts erb.result
    end
    puts "write to #{config.nginx_conf}"
  end

  namespace:minjs do
    def minjs from, to
      sh "java -jar scripts/compiler.jar --js=#{from} --js_output_file=#{to}"
    end

    desc "dashboard"
    task:dashboard do
      minjs "public/emark.jp/dashboard/index.js", "public/emark.jp/dashboard/index.min.js"
    end

    desc "octopress"
    task:octopress do
      minjs "public/emark.jp/octopress/index.js", "public/emark.jp/octopress/index.min.js"
    end
  end
end
desc "build"
task:build => [
  "build:nginx",
  "assets"
]
task:build do
  require "./config/environment"
  if "production" == config.environment
    Rake::Task["build::minjs::dashboard"]
    Rake::Task["build::minjs::octopress"]
  end
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

