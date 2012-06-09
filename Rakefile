require "pp"

desc "install"
task :install do
  sh "bundle install --path vender/bundle"
end

task :default => :spec
task :spec => :init

desc "init"
task :init do
  sh "bundle exec rake db:migrate RAILS_ENV=spec"
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

desc "sprockets"
task:sprockets do
  require "bundler"
  Bundler.require :sprockets

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
  end

  path = "public/emark.jp/js/application.js"
  mkdir_p File.dirname(path)
  File.open path, "w" do |fp|
    fp.puts environment["application.js"].to_s
  end
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
