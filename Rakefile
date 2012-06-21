require "pp"

namespace:assets do
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

    ##
    # octopress
    content   = environment["octopress.js"].to_s
    pp content
    octopress = "public/emark.jp/octopress.js"
    File.open octopress, "w" do |fp|
      fp.write content
    end

    ##
    # dashboard

  end
end

__END__

desc "install"
task :install do
  sh "bundle install --path vender/bundle"
end

task :default => :spec
task :spec => :init

desc "init"
task :init do
  sh "bundle exec rake db:migrate RAILS_ENV=test"
end

begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec) do |spec|
    spec.pattern = "spec/spec.rb"
    spec.rspec_opts = ["-cfs"]
  end
rescue LoadError => e
  puts "can't load rake_task"
end

begin
  require 'tasks/standalone_migrations'
rescue LoadError => e
  puts "gem install standalone_migrations to get db:migrate:* tasks! (Error: #{e})"
end

desc "nginx"
task :nginx do
  require "erb"
  require "./config/environment"

  erb = ERB.new File.read("./config/emark.conf.erb")
  File.open config.nginx_conf, "w" do |f|
    f.puts erb.result
  end
  puts "write to #{config.nginx_conf}"
end

desc "config_js"
task :config_js do
  require "erb"
  require "./config/environment"

  path = "app/assets/javascripts/config.js"

  erb = ERB.new File.read("./config/config.js.erb")
  File.open path, "w" do |fp|
    fp.puts erb.result
  end
  puts "write to #{path}"
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

