
desc "install"
task :install do
  sh "bundle install --path vender/bundle"
end

desc "test"
task :test do
  sh "bundle exec rspec spec/suites/spec.rb"
end

begin
  require 'tasks/standalone_migrations'
rescue LoadError => e
  puts "gem install standalone_migrations to get db:migrate:* tasks! (Error: #{e})"
end
