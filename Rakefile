desc "install"
task :install do
  sh "bundle install --path vender/bundle"
end

desc "test"
task :test do
  sh "bundle exec rspec spec/suites/spec.rb"
end

namespace:spec do
  desc "spec:open"
  task:open do
    sh "bundle exec rspec -cfs spec/suites/spec2.rb"
  end
end

# begin
#   require "rspec/core/rake_task"
#   RSpec::Core::RakeTask.new(:spec) do |spec|
#     spec.pattern = "spec/suites/*.rb"
#     spec.rspec_opts = ["-cfs"]
#   end
# rescue LoadError => e
#   puts "can't load rake_task"
# end

begin
  require 'tasks/standalone_migrations'
rescue LoadError => e
  puts "gem install standalone_migrations to get db:migrate:* tasks! (Error: #{e})"
end
