source 'https://rubygems.org'

gem "arel"
gem "hashie"
gem "sqlite3"
gem "oauth"
gem "thrift", :git => "git://github.com/McRipper/thrift-1.9.3.git"
gem "thrift_client", "~> 0.8.1", :git => "git://github.com/McRipper/thrift_client.git"
gem "activerecord", :require => "active_record"
gem "eventmachine"
gem "addressable", :require => "addressable/uri"

group :http do
  gem "rack-fiber_pool", :require => "rack/fiber_pool"
  gem "rack-ssl", :require => "rack/ssl"
  gem "sinatra"
end

group :publish do
  gem "nokogiri"
  gem "haml"
  gem "rdiscount"
end

group :rails do
end

group :assets do
  gem "haml"
  gem "sass"
  gem "eco"
  gem "ejs"
  gem "sprockets"
  gem "haml_coffee_assets"
  gem "rb-fsevent"
  gem "rails",        :require => false
  gem "spine-rails",  :require => false
  gem "jquery-rails", :require => false
end

group :test do
  gem 'ruby-debug19'
  gem 'ruby-debug-base19x', '>= 0.11.30.pre10'
  gem 'linecache19', git: 'https://github.com/mark-moseley/linecache.git', ref: '869c6a65155068415925067e480741bd0a71527e'
  gem "rack-test", :require => "rack/test"
end

group :cli do
  gem "rails"
  gem "standalone_migrations"
  gem "thin"
  gem "watchr"
  gem "simplecov"
  gem "rspec"
  gem "jasmine"
  gem "jasmine-headless-webkit"
  gem "rb-fsevent"
  gem "guard"
  gem "guard-shell"
  gem "guard-rspec"
  gem "guard-jasmine-headless-webkit"
  gem "guard-haml"
end

