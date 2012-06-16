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
end


group :sprockets do
  gem "rails"
  gem "eco"
  gem "ejs"
  gem "sprockets"
  gem "spine-rails"
  gem "jquery-rails"
end

group :test do
  gem "rack-test", :require => "rack/test"
end

group :cli do
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
end

