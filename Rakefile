desc "install"
task :install do
  sh "bundle install --path vender/bundle"
end

task :default => :spec

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
