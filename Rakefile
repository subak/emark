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
